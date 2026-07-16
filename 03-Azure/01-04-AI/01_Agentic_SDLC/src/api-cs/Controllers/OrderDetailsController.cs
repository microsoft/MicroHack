using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/order-details")]
public sealed class OrderDetailsController(OrderDetailsRepository repository) : ControllerBase
{
    private readonly OrderDetailsRepository _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<OrderDetail>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<OrderDetail>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("OrderDetail", id) : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<OrderDetail>> Create([FromBody] CreateOrderDetailRequest request)
    {
        if (request.OrderId <= 0 || request.ProductId <= 0)
        {
            throw new ValidationException("orderId and productId are required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.OrderDetailId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<OrderDetail>> Update(int id, [FromBody] UpdateOrderDetailRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
