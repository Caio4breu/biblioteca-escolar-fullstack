package br.edu.biblioteca.backend.livro;

import java.util.List;

import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

@RestController
@RequestMapping("/api/livros")
public class LivroController {

    public record LivroRequest(
        @NotBlank String titulo,
        @NotBlank String autor,
        String isbn,
        @NotNull @Min(0) Integer exemplaresTotal) {
    }

    private final LivroRepository repo;

    public LivroController(LivroRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<Livro> listar() {
        return repo.findAll(Sort.by("id"));
    }

    @GetMapping("/{id}")
    public Livro buscar(@PathVariable Integer id) {
        return achar(id);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Livro criar(@Valid @RequestBody LivroRequest req) {
        Livro l = new Livro();
        preencher(l, req);
        l.setExemplaresDisponiveis(req.exemplaresTotal());
        return repo.save(l);
    }

    @PutMapping("/{id}")
    public Livro atualizar(@PathVariable Integer id, @Valid @RequestBody LivroRequest req) {
        Livro l = achar(id);
        int diferenca = req.exemplaresTotal() - l.getExemplaresTotal();
        int novosDisponiveis = l.getExemplaresDisponiveis() + diferenca;
        if (novosDisponiveis < 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Total de exemplares menor que a quantidade emprestada");
        }
        preencher(l, req);
        l.setExemplaresDisponiveis(novosDisponiveis);
        return repo.save(l);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@PathVariable Integer id) {
        repo.delete(achar(id));
    }

    private Livro achar(Integer id) {
        return repo.findById(id).orElseThrow(
            () -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Livro nao encontrado"));
    }

    private void preencher(Livro l, LivroRequest req) {
        l.setTitulo(req.titulo());
        l.setAutor(req.autor());
        l.setIsbn(req.isbn() == null || req.isbn().isBlank() ? null : req.isbn());
        l.setExemplaresTotal(req.exemplaresTotal());
    }
}
