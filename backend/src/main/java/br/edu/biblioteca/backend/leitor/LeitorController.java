package br.edu.biblioteca.backend.leitor;

import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

@RestController
@RequestMapping("/api/leitores")
public class LeitorController {

    public record LeitorRequest(@NotBlank String nome, @NotBlank String cpf, String email) {
    }

    private final JdbcTemplate jdbc;
    private final String cpfKey;

    public LeitorController(JdbcTemplate jdbc, @Value("${app.cpf-key}") String cpfKey) {
        this.jdbc = jdbc;
        this.cpfKey = cpfKey;
    }

    // O CPF nunca e devolvido: fica criptografado no banco (pgcrypto)
    @GetMapping
    public List<Map<String, Object>> listar() {
        return jdbc.queryForList(
            "SELECT id, nome, email, ativo FROM biblioteca.leitor ORDER BY id");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Map<String, Object> criar(@Valid @RequestBody LeitorRequest req) {
        Integer id = jdbc.queryForObject(
            "INSERT INTO biblioteca.leitor (nome, cpf_cript, email) "
          + "VALUES (?, extensions.pgp_sym_encrypt(?::text, ?::text), ?) RETURNING id",
            Integer.class, req.nome(), req.cpf(), cpfKey, req.email());
        return Map.of("id", id, "nome", req.nome());
    }
}
