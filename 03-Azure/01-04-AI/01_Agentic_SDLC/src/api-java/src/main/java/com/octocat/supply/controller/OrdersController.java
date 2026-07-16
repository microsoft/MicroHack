package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.OrderModel.CreateOrderRequest;
import com.octocat.supply.model.OrderModel.Order;
import com.octocat.supply.model.OrderModel.UpdateOrderRequest;
import com.octocat.supply.repository.OrdersRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/orders")
public class OrdersController {
    private final OrdersRepository repository;

    public OrdersController(OrdersRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Order> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public Order getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Order not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public Order create(@RequestBody CreateOrderRequest request) {
        ControllerValidation.requireText(request.name(), "name");
        ControllerValidation.requirePositive(request.branchId(), "branchId");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public Order update(@PathVariable int id, @RequestBody UpdateOrderRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("Order not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("Order not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("Order not found");
        }
    }
}
