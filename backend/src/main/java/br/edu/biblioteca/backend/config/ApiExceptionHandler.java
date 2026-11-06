package br.edu.biblioteca.backend.config;

import java.util.Map;

import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class ApiExceptionHandler {

    // Erros do banco (RAISE EXCEPTION de triggers/procedures, FK, CHECK, permissao)
    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<Map<String, String>> banco(DataAccessException e) {
        String msg = NestedExceptionUtils.getMostSpecificCause(e).getMessage();
        if (msg == null) {
            msg = "Erro ao acessar o banco de dados";
        }
        msg = msg.lines().findFirst().orElse(msg).replaceFirst("^ERROR:\\s*", "");
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("erro", msg));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, String>> validacao(MethodArgumentNotValidException e) {
        String msg = e.getBindingResult().getFieldErrors().stream()
            .map(f -> f.getField() + ": " + f.getDefaultMessage())
            .findFirst().orElse("Dados invalidos");
        return ResponseEntity.badRequest().body(Map.of("erro", msg));
    }
}
