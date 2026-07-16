package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.BranchModel.Branch;
import com.octocat.supply.model.BranchModel.CreateBranchRequest;
import com.octocat.supply.model.BranchModel.UpdateBranchRequest;
import com.octocat.supply.repository.BranchesRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/branches")
public class BranchesController {
    private final BranchesRepository repository;

    public BranchesController(BranchesRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Branch> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Branch getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Branch not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Branch create(@RequestBody CreateBranchRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Branch update(@PathVariable int id, @RequestBody UpdateBranchRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Branch not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Branch not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Branch not found");
        }
    }
}
