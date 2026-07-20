package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.ProductModel.CreateProductRequest;
import com.octocat.supply.model.ProductModel.Product;
import com.octocat.supply.model.ProductModel.UpdateProductRequest;
import com.octocat.supply.repository.ProductsRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/products")
public class ProductsController {
    private final ProductsRepository repository;

    public ProductsController(ProductsRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Product> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Product getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Product not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Product create(@RequestBody CreateProductRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Product update(@PathVariable int id, @RequestBody UpdateProductRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Product not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Product not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Product not found");
        }
    }
}
