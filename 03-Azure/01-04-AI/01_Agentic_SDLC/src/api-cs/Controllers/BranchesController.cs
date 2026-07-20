using Microsoft.AspNetCore.Mvc;
using OctoSupply.Api.Models;
using OctoSupply.Api.Repositories;
using OctoSupply.Api.Utils;

namespace OctoSupply.Api.Controllers;

[ApiController]
[Route("api/branches")]
public sealed class BranchesController(BranchesRepository repository) : ControllerBase
{
    private readonly BranchesRepository _repository = repository;

    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<Branch>>> GetAll() =>
        Ok(await _repository.FindAllAsync());

    [HttpGet("{id:int}")]
    public async Task<ActionResult<Branch>> GetById(int id)
    {
        var item = await _repository.FindByIdAsync(id);
        return item is null ? throw new NotFoundException("Branch", id) : Ok(item);
    }

    [HttpPost]
    public async Task<ActionResult<Branch>> Create([FromBody] CreateBranchRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
        {
            throw new ValidationException("name is required");
        }

        var created = await _repository.CreateAsync(request);
        return CreatedAtAction(nameof(GetById), new { id = created.BranchId }, created);
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<Branch>> Update(int id, [FromBody] UpdateBranchRequest request) =>
        Ok(await _repository.UpdateAsync(id, request));

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        await _repository.DeleteAsync(id);
        return NoContent();
    }
}
