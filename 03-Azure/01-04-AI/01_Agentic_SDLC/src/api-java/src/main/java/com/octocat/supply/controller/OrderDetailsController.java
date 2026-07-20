package com.octocat.supply.controller;

import com.octocat.supply.exception.NotFoundException;
import com.octocat.supply.model.OrderDetailModel.CreateOrderDetailRequest;
import com.octocat.supply.model.OrderDetailModel.OrderDetail;
import com.octocat.supply.model.OrderDetailModel.UpdateOrderDetailRequest;
import com.octocat.supply.repository.OrderDetailsRepository;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/order-details")
public class OrderDetailsController {
    private final OrderDetailsRepository repository;

    public OrderDetailsController(OrderDetailsRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<OrderDetail> getAll() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public OrderDetail getById(@PathVariable int id) {
        return repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetail not found"));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderDetail create(@RequestBody CreateOrderDetailRequest request) {
        ControllerValidation.requirePositive(request.orderId(), "orderId");
        ControllerValidation.requirePositive(request.productId(), "productId");
        return repository.create(request);
    }

    @PutMapping("/{id}")
    public OrderDetail update(@PathVariable int id, @RequestBody UpdateOrderDetailRequest request) {
        repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetail not found"));
        repository.update(id, request);
        return repository.findById(id).orElseThrow(() -> new NotFoundException("OrderDetail not found"));
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable int id) {
        if (!repository.delete(id)) {
            throw new NotFoundException("OrderDetail not found");
        }
    }
}
