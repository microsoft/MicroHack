package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.SupplierModel.CreateSupplierRequest;
import com.octocat.supply.model.SupplierModel.Supplier;
import com.octocat.supply.model.SupplierModel.UpdateSupplierRequest;
import com.octocat.supply.repository.SuppliersRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/suppliers")
public class SuppliersController {
    private final SuppliersRepository repository;

    public SuppliersController(SuppliersRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Supplier> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Supplier getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Supplier not found"));
    }

    @GetMapping("/{id}/status")
    public Map<String, String> getStatus(@PathVariable int id) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Supplier not found"));
        return Map.of("status", "APPROVED");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Supplier create(@RequestBody CreateSupplierRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Supplier update(@PathVariable int id, @RequestBody UpdateSupplierRequest request) {
        if (!repository.findById(id).isPresent()) {
            throw new NotFoundException("Supplier not found");
        }
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Supplier not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Supplier not found");
        }
    }
}
