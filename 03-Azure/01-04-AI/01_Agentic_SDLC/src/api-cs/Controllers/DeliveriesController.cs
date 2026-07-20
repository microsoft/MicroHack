using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/deliveries")]
public sealed class DeliveriesController(DeliveriesRepository repository) : ControllerBase
{
    private readonly DeliveriesRepository _repository = repository;

    public sealed class UpdateDeliveryStatusRequest
    {
        public string Status { get; set; } = string.Empty;
        public string? DeliveryPartner { get; set; }
    }

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<Delivery>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Delivery>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("Delivery", id) : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<Delivery>> Create([FromBody] CreateDeliveryRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ValidationException("name is required");
        }

        if (string.IsNullOrWhiteSpace(request.DeliveryDate))
        {
            throw new ValidationException("deliveryDate is required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.DeliveryId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Delivery>> Update(int id, [FromBody] UpdateDeliveryRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpPut("{id:int}/status")]
    public async Task<ActionResult<Delivery>> UpdateStatus(int id, [FromBody] UpdateDeliveryStatusRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Status))
        {
            throw new ValidationException("status is required");
        }

        var updated = await _repository.UpdateStatusAsync(id, request.Status);
        if (!string.IsNullOrWhiteSpace(request.DeliveryPartner))
        {
            return Ok(new { delivery = updated, commandOutput = string.Empty });
        }

        return Ok(updated);
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
