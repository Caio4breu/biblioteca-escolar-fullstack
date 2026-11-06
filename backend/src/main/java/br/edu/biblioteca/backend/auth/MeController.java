package br.edu.biblioteca.backend.auth;

import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class MeController {

    private final JdbcTemplate jdbc;

    public MeController(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // Usado pelo frontend para validar o login
    @GetMapping("/api/me")
    public Map<String, Object> me(Authentication auth) {
        return jdbc.queryForMap(
            "SELECT nome, email, perfil FROM biblioteca.operador WHERE email = ?", auth.getName());
    }
}
