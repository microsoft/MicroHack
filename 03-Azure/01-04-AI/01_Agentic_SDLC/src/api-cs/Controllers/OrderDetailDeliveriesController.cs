using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/order-detail-deliveries")]
public sealed class OrderDetailDeliveriesController(OrderDetailDeliveriesRepository repository) : ControllerBase
{
    private readonly OrderDetailDeliveriesRepository _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<OrderDetailDelivery>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDetailDelivery>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("OrderDetailDelivery", id) : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<OrderDetailDelivery>> Create([FromBody] CreateOrderDetailDeliveryRequest request)
    {
        if (request.OrderDetailId <= 0 || request.DeliveryId <= 0)
        {
            throw new ValidationException("orderDetailId and deliveryId are required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.OrderDetailDeliveryId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<OrderDetailDelivery>> Update(int id, [FromBody] UpdateOrderDetailDeliveryRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
