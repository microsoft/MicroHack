package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.DeliveryModel.CreateDeliveryRequest;
import com.octocat.supply.model.DeliveryModel.Delivery;
import com.octocat.supply.model.DeliveryModel.UpdateDeliveryRequest;
import com.octocat.supply.model.DeliveryModel.UpdateDeliveryStatusRequest;
import com.octocat.supply.repository.DeliveriesRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/deliveries")
public class DeliveriesController {
    private final DeliveriesRepository repository;

    public DeliveriesController(DeliveriesRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Delivery> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Delivery getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Delivery not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Delivery create(@RequestBody CreateDeliveryRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        ControllerValidation.requireText(request.deliveryDate(), "deliveryDate");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Delivery update(@PathVariable int id, @RequestBody UpdateDeliveryRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Delivery not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Delivery not found"));
    }

    @PutMapping("/{id}/status")
    public Object updateStatus(@PathVariable int id, @RequestBody UpdateDeliveryStatusRequest request) {
        ControllerValidation.requireText(request.status(), "status");
        repository.findById(id).orElseThrow(() -> new NotFoundException("Delivery not found"));
        repository.updateStatus(id, request.status());
        Delivery updated = repository.findById(id).orElseThrow(() -> new NotFoundException("Delivery not found"));
        if (request.deliveryPartner() != null && !request.deliveryPartner().isBlank()) {
            Map<String, Object> response = new LinkedHashMap<>();
            response.put("delivery", updated);
            response.put("commandOutput", "");
            return response;
        }
        return updated;
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Delivery not found");
        }
    }
}
