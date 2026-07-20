package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.OrderDetailDeliveryModel.CreateOrderDetailDeliveryRequest;
import com.octocat.supply.model.OrderDetailDeliveryModel.OrderDetailDelivery;
import com.octocat.supply.model.OrderDetailDeliveryModel.UpdateOrderDetailDeliveryRequest;
import com.octocat.supply.repository.OrderDetailDeliveriesRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/order-detail-deliveries")
public class OrderDetailDeliveriesController {
    private final OrderDetailDeliveriesRepository repository;

    public OrderDetailDeliveriesController(OrderDetailDeliveriesRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<OrderDetailDelivery> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public OrderDetailDelivery getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetailDelivery not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderDetailDelivery create(@RequestBody CreateOrderDetailDeliveryRequest request) {
        ControllerValidation.requirePositive(request.orderDetailId(), "orderDetailId");
        ControllerValidation.requirePositive(request.deliveryId(), "deliveryId");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public OrderDetailDelivery update(@PathVariable int id, @RequestBody UpdateOrderDetailDeliveryRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetailDelivery not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetailDelivery not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("OrderDetailDelivery not found");
        }
    }
}
