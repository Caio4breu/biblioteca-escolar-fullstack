-- =====================================================================
-- backup.sql - Biblioteca Escolar (carga inicial: DDL, DML, programacao, seeds)
-- Executado automaticamente na primeira subida do container db.
-- =====================================================================

-- ============ SCHEMAS E EXTENSOES ============
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS biblioteca;
CREATE SCHEMA IF NOT EXISTS audit;

-- pgcrypto fica em schema proprio para o schema public poder ser trancado
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA extensions;

-- ============ TABELAS ============
CREATE TABLE biblioteca.operador (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    email       VARCHAR(120) NOT NULL UNIQUE,
    senha_hash  TEXT NOT NULL,
    perfil      VARCHAR(20) NOT NULL DEFAULT 'ATENDENTE'
);

CREATE TABLE biblioteca.livro (
    id                       SERIAL PRIMARY KEY,
    titulo                   VARCHAR(200) NOT NULL,
    autor                    VARCHAR(120) NOT NULL,
    isbn                     VARCHAR(20) UNIQUE,
    exemplares_total         INT NOT NULL CHECK (exemplares_total >= 0),
    exemplares_disponiveis   INT NOT NULL CHECK (exemplares_disponiveis >= 0)
);

-- CPF criptografado com pgcrypto
CREATE TABLE biblioteca.leitor (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(100) NOT NULL,
    cpf_cript   BYTEA NOT NULL,
    email       VARCHAR(120),
    ativo       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE biblioteca.emprestimo (
    id                SERIAL PRIMARY KEY,
    livro_id          INT NOT NULL REFERENCES biblioteca.livro(id),
    leitor_id         INT NOT NULL REFERENCES biblioteca.leitor(id),
    operador_id       INT NOT NULL REFERENCES biblioteca.operador(id),
    data_emprestimo   DATE NOT NULL DEFAULT CURRENT_DATE,
    data_prevista     DATE NOT NULL,
    data_devolucao    DATE,
    status            VARCHAR(20) NOT NULL DEFAULT 'ABERTO'
);

CREATE TABLE biblioteca.multa (
    id              SERIAL PRIMARY KEY,
    emprestimo_id   INT NOT NULL REFERENCES biblioteca.emprestimo(id),
    dias_atraso     INT NOT NULL,
    valor           NUMERIC(10,2) NOT NULL
);

CREATE TABLE audit.log_emprestimo (
    id            SERIAL PRIMARY KEY,
    emprestimo_id INT NOT NULL,
    acao          VARCHAR(10) NOT NULL,
    status_antigo VARCHAR(20),
    status_novo   VARCHAR(20),
    usuario_bd    TEXT NOT NULL DEFAULT current_user,
    data_hora     TIMESTAMP NOT NULL DEFAULT now()
);

-- ============ FUNCTION ============
-- Multa: R$ 2,00 por dia de atraso
CREATE OR REPLACE FUNCTION biblioteca.fn_calcular_multa(
    p_data_prevista  DATE,
    p_data_devolucao DATE
) RETURNS NUMERIC AS $$
BEGIN
    IF p_data_devolucao <= p_data_prevista THEN
        RETURN 0;
    END IF;
    RETURN (p_data_devolucao - p_data_prevista) * 2.00;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============ PROCEDURE ============
CREATE OR REPLACE PROCEDURE biblioteca.sp_realizar_devolucao(p_emprestimo_id INT)
LANGUAGE plpgsql AS $$
DECLARE
    v_emp   biblioteca.emprestimo%ROWTYPE;
    v_dias  INT;
    v_valor NUMERIC;
BEGIN
    SELECT * INTO v_emp FROM biblioteca.emprestimo
    WHERE id = p_emprestimo_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Emprestimo % nao encontrado', p_emprestimo_id;
    END IF;
    IF v_emp.status = 'DEVOLVIDO' THEN
        RAISE EXCEPTION 'Emprestimo % ja foi devolvido', p_emprestimo_id;
    END IF;

    v_dias  := GREATEST(CURRENT_DATE - v_emp.data_prevista, 0);
    v_valor := biblioteca.fn_calcular_multa(v_emp.data_prevista, CURRENT_DATE);

    UPDATE biblioteca.emprestimo
       SET data_devolucao = CURRENT_DATE, status = 'DEVOLVIDO'
     WHERE id = p_emprestimo_id;

    UPDATE biblioteca.livro
       SET exemplares_disponiveis = exemplares_disponiveis + 1
     WHERE id = v_emp.livro_id;

    IF v_valor > 0 THEN
        INSERT INTO biblioteca.multa (emprestimo_id, dias_atraso, valor)
        VALUES (p_emprestimo_id, v_dias, v_valor);
    END IF;
END;
$$;

-- ============ TRIGGERS ============
-- 1) Auditoria de emprestimos
CREATE OR REPLACE FUNCTION audit.fn_log_emprestimo() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit.log_emprestimo (emprestimo_id, acao, status_novo)
        VALUES (NEW.id, 'INSERT', NEW.status);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit.log_emprestimo (emprestimo_id, acao, status_antigo, status_novo)
        VALUES (NEW.id, 'UPDATE', OLD.status, NEW.status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_emprestimo
AFTER INSERT OR UPDATE ON biblioteca.emprestimo
FOR EACH ROW EXECUTE FUNCTION audit.fn_log_emprestimo();

-- 2) Baixa de exemplar ao emprestar (bloqueia se nao houver disponivel)
CREATE OR REPLACE FUNCTION biblioteca.fn_baixa_exemplar() RETURNS TRIGGER AS $$
BEGIN
    UPDATE biblioteca.livro
       SET exemplares_disponiveis = exemplares_disponiveis - 1
     WHERE id = NEW.livro_id AND exemplares_disponiveis > 0;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Livro % sem exemplares disponiveis', NEW.livro_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_baixa_exemplar
BEFORE INSERT ON biblioteca.emprestimo
FOR EACH ROW EXECUTE FUNCTION biblioteca.fn_baixa_exemplar();

-- ============ VIEWS ============
CREATE OR REPLACE VIEW biblioteca.vw_emprestimos_atrasados AS
SELECT e.id, l.titulo, r.nome AS leitor, e.data_prevista,
       (CURRENT_DATE - e.data_prevista) AS dias_atraso
FROM biblioteca.emprestimo e
JOIN biblioteca.livro l  ON l.id = e.livro_id
JOIN biblioteca.leitor r ON r.id = e.leitor_id
WHERE e.status = 'ABERTO' AND e.data_prevista < CURRENT_DATE;

CREATE OR REPLACE VIEW biblioteca.vw_livros_disponiveis AS
SELECT id, titulo, autor, exemplares_disponiveis
FROM biblioteca.livro
WHERE exemplares_disponiveis > 0;

-- ============ ROLES E PERMISSOES (RBAC) ============
CREATE ROLE rl_atendente NOLOGIN;
CREATE ROLE rl_consulta  NOLOGIN;

CREATE USER app_atendente WITH PASSWORD 'atendente123' IN ROLE rl_atendente;
CREATE USER app_consulta  WITH PASSWORD 'consulta123'  IN ROLE rl_consulta;

-- Timeout mais curto para o usuario de consulta (relatorios pesados)
ALTER ROLE app_consulta SET statement_timeout = '5s';

-- Hardening: ninguem usa o schema public nem conecta sem permissao
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE biblioteca FROM PUBLIC;
GRANT CONNECT ON DATABASE biblioteca TO rl_atendente, rl_consulta;

-- Atendente: leitura e escrita no schema biblioteca
GRANT USAGE ON SCHEMA biblioteca TO rl_atendente;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA biblioteca TO rl_atendente;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA biblioteca TO rl_atendente;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA biblioteca TO rl_atendente;

-- Triggers rodam com a permissao de quem altera: precisa gravar no audit
GRANT USAGE ON SCHEMA audit TO rl_atendente;
GRANT INSERT ON audit.log_emprestimo TO rl_atendente;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO rl_atendente;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA audit TO rl_atendente;

-- pgcrypto (criptografia do CPF)
GRANT USAGE ON SCHEMA extensions TO rl_atendente;

-- Consulta: somente leitura do catalogo
GRANT USAGE ON SCHEMA biblioteca TO rl_consulta;
GRANT SELECT ON biblioteca.livro TO rl_consulta;
GRANT SELECT ON biblioteca.vw_livros_disponiveis TO rl_consulta;

