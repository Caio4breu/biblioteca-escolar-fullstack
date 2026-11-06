package br.edu.biblioteca.backend.livro;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "livro", schema = "biblioteca")
public class Livro {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Integer id;

    @Column(nullable = false)
    private String titulo;

    @Column(nullable = false)
    private String autor;

    private String isbn;

    @Column(name = "exemplares_total", nullable = false)
    private Integer exemplaresTotal;

    @Column(name = "exemplares_disponiveis", nullable = false)
    private Integer exemplaresDisponiveis;

    public Integer getId() { return id; }
    public String getTitulo() { return titulo; }
    public void setTitulo(String titulo) { this.titulo = titulo; }
    public String getAutor() { return autor; }
    public void setAutor(String autor) { this.autor = autor; }
    public String getIsbn() { return isbn; }
    public void setIsbn(String isbn) { this.isbn = isbn; }
    public Integer getExemplaresTotal() { return exemplaresTotal; }
    public void setExemplaresTotal(Integer exemplaresTotal) { this.exemplaresTotal = exemplaresTotal; }
    public Integer getExemplaresDisponiveis() { return exemplaresDisponiveis; }
    public void setExemplaresDisponiveis(Integer exemplaresDisponiveis) { this.exemplaresDisponiveis = exemplaresDisponiveis; }
}
