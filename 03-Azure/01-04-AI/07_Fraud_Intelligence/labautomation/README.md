# Lab automation

This folder is optional. Delete it if this MicroHack does not need automated Azure provisioning.

When present, the MicroHack platform reads [lab-defaults.json](lab-defaults.json) to determine how to scope lab environments. It invokes [deploy-lab.ps1](deploy-lab.ps1) once per participant and, when present, [shared-deploy-lab.ps1](shared-deploy-lab.ps1) once per subscription before participant deployments begin.

## Folder layout

```text
labautomation/
|-- lab-defaults.json        # Platform-facing configuration
|-- deploy-lab.ps1           # Per-participant deployment hook
|-- shared-deploy-lab.ps1    # Optional per-subscription deployment hook
`-- main.bicep               # MicroHack-specific infrastructure
```

## Authoring guidance

- Keep each participant deployment isolated.
- Put shared resources and one-time subscription preparation in `shared-deploy-lab.ps1`.
- Use `Get-MhhStableHash` when deterministic per-participant resource names are required.
- Return participant-facing values as `HackboxCredential` hashtables.
- Never return participant-specific secrets from the shared deployment hook.

For the complete platform contract and helper cmdlet reference, see the [upstream MicroHack template documentation](https://github.com/microsoft/MicroHack/blob/main/99-MicroHack-Template/labautomation/README.md).