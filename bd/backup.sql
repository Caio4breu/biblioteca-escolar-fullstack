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

