package br.edu.biblioteca.backend.emprestimo;

import java.util.List;
import java.util.Map;

import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

@RestController
@RequestMapping("/api/emprestimos")
public class EmprestimoController {

    public record EmprestimoRequest(
        @NotNull Integer livroId,
        @NotNull Integer leitorId,
        @Min(1) Integer prazoDias) {
    }

    private final JdbcTemplate jdbc;

    public EmprestimoController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(
            "SELECT e.id, l.titulo, r.nome AS leitor, e.data_emprestimo::text AS data_emprestimo, "
          + "e.data_prevista::text AS data_prevista, e.data_devolucao::text AS data_devolucao, e.status, "
          + "COALESCE(m.valor, 0) AS multa "
          + "FROM biblioteca.emprestimo e "
          + "JOIN biblioteca.livro l ON l.id = e.livro_id "
          + "JOIN biblioteca.leitor r ON r.id = e.leitor_id "
          + "LEFT JOIN biblioteca.multa m ON m.emprestimo_id = e.id "
          + "ORDER BY e.id DESC");
    }

    // Usa a view vw_emprestimos_atrasados
    @GetMapping("/atrasados")
    public List<Map<String, Object>> atrasados() {
        return jdbc.queryForList("SELECT id, titulo, leitor, data_prevista::text AS data_prevista, dias_atraso, "
          + "biblioteca.fn_calcular_multa(data_prevista, CURRENT_DATE) AS multa_estimada "
          + "FROM biblioteca.vw_emprestimos_atrasados ORDER BY id");
    }

    // O trigger trg_baixa_exemplar baixa o estoque e bloqueia livro sem exemplar
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> criar(@Valid @RequestBody EmprestimoRequest req, Authentication auth) {
        int prazo = req.prazoDias() == null ? 7 : req.prazoDias();
        Integer id = jdbc.queryForObject(
            "INSERT INTO biblioteca.emprestimo (livro_id, leitor_id, operador_id, data_prevista) "
          + "VALUES (?, ?, (SELECT id FROM biblioteca.operador WHERE email = ?), CURRENT_DATE + ?) "
          + "RETURNING id",
            Integer.class, req.livroId(), req.leitorId(), auth.getName(), prazo);
        return Map.of("id", id);
    }

    // Chama a procedure sp_realizar_devolucao (calcula atraso e multa no banco)
    @PostMapping("/{id}/devolucao")
    public Map<String, Object> devolver(@PathVariable Integer id) {
        jdbc.update("CALL biblioteca.sp_realizar_devolucao(?)", id);
        var multas = jdbc.queryForList(
            "SELECT dias_atraso, valor FROM biblioteca.multa WHERE emprestimo_id = ?", id);
        if (multas.isEmpty()) {
            return Map.of("emprestimoId", id, "diasAtraso", 0, "multa", 0);
        }
        return Map.of("emprestimoId", id,
            "diasAtraso", multas.get(0).get("dias_atraso"),
            "multa", multas.get(0).get("valor"));
    }
}
