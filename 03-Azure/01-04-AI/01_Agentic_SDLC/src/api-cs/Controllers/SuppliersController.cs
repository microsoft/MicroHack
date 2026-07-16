using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/suppliers")]
public sealed class SuppliersController(SuppliersRepository repository) : ControllerBase
{
    private readonly SuppliersRepository _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<Supplier>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Supplier>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("Supplier", id) : Ok(item);
    }

    [HttpGet("{id:int}/status")]
    public async Task<ActionResult<object>> GetStatus(int id)
    {
        var supplier = await _repository.FindByIdAsync(id);
        if (supplier is null)
        {
            throw new NotFoundException("Supplier", id);
        }

        // Mirrors TypeScript behavior where status currently always resolves to APPROVED.
        return Ok(new { status = "APPROVED" });
    }

    [HttpPost]
    public async Task<ActionResult<Supplier>> Create([FromBody] CreateSupplierRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ValidationException("name is required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.SupplierId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Supplier>> Update(int id, [FromBody] UpdateSupplierRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
