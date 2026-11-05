using 'main.bicep'

// Example only; deploy-lab.ps1 derives the real suffix from the assigned lab scope.
param labSuffix = 'lab00001'

param participantObjectIds = [
  '<participant Entra object ID>'
]

param windowsAdminUsername = 'HVAdmin'

param windowsAdminPassword = '<your windows admin password>'

param flavor = 'ITPro'

param deployBastion = true

param vmAutologon = true
