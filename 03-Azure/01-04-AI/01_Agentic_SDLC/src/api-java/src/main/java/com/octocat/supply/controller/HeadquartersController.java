package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.HeadquartersModel.CreateHeadquartersRequest;
import com.octocat.supply.model.HeadquartersModel.Headquarters;
import com.octocat.supply.model.HeadquartersModel.HeadquartersMetrics;
import com.octocat.supply.model.HeadquartersModel.UpdateHeadquartersRequest;
import com.octocat.supply.repository.HeadquartersRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/headquarters")
public class HeadquartersController {
    private final HeadquartersRepository repository;

    public HeadquartersController(HeadquartersRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Headquarters> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Headquarters getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Headquarters not found"));
    }

    @GetMapping("/{id}/metrics")
    public HeadquartersMetrics metrics(@PathVariable int id) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Headquarters not found"));
        return repository.metrics(id);
    }

    @GetMapping("/{id}/label")
    public Map<String, String> label(@PathVariable int id) {
        Headquarters headquarters = repository.findById(id).orElseThrow(() -> new NotFoundException("Headquarters not found"));
        return Map.of("label", "Location:" + headquarters.name() + "City:Country:");
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Headquarters create(@RequestBody CreateHeadquartersRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Headquarters update(@PathVariable int id, @RequestBody UpdateHeadquartersRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Headquarters not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Headquarters not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Headquarters not found");
        }
    }
}
