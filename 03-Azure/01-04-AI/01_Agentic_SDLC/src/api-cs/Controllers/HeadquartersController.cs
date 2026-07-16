using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/headquarters")]
public sealed class HeadquartersController(HeadquartersRepository repository) : ControllerBase
{
    private readonly HeadquartersRepository _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<Headquarters>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Headquarters>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("Headquarters", id) : Ok(item);
    }

    [HttpGet("{id:int}/metrics")]
    public async Task<ActionResult<object>> GetMetrics(int id) =>
        Ok(await _repository.GetMetricsAsync(id));

    [HttpGet("{id:int}/label")]
    public async Task<ActionResult<object>> GetLabel(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        if (item is null)
        {
            throw new NotFoundException("Headquarters", id);
        }

        var label = $"Location:{item.Name}City:Country:";
        return Ok(new { label });
    }

    [HttpPost]
    public async Task<ActionResult<Headquarters>> Create([FromBody] CreateHeadquartersRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ValidationException("name is required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.HeadquartersId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Headquarters>> Update(int id, [FromBody] UpdateHeadquartersRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
