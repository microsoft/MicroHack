#######################################################################
## Values to print at the end of the execution
#######################################################################

output "public_ip_address" {
  value = data.azurerm_public_ip.gw-ip.ip_address
}