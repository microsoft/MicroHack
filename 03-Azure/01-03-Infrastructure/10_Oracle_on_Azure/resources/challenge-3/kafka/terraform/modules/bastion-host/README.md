

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_password"></a> [admin\_password](#input\_admin\_password) | admin password | `string` | `"Password123"` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | admin username | `string` | `"azureuser"` | no |
| <a name="input_assigned_roles"></a> [assigned\_roles](#input\_assigned\_roles) | list of assigned roles | <pre>list(object({<br>    role  = string<br>    scope = string<br>  }))</pre> | `[]` | no |
| <a name="input_computer_name"></a> [computer\_name](#input\_computer\_name) | computer name | `string` | `""` | no |
| <a name="input_custom_data"></a> [custom\_data](#input\_custom\_data) | base64 string containing virtual machine custom data | `string` | `null` | no |
| <a name="input_dns_servers"></a> [dns\_servers](#input\_dns\_servers) | DNS servers | `list(any)` | `null` | no |
| <a name="input_enable_ipv6"></a> [enable\_ipv6](#input\_enable\_ipv6) | enable dual stack networking | `bool` | `false` | no |
| <a name="input_enable_plan"></a> [enable\_plan](#input\_enable\_plan) | enable plan | `bool` | `false` | no |
| <a name="input_enable_public_ip"></a> [enable\_public\_ip](#input\_enable\_public\_ip) | enable public ip interface | `bool` | `false` | no |
| <a name="input_images_with_plan"></a> [images\_with\_plan](#input\_images\_with\_plan) | images with plan | `list(string)` | <pre>[<br>  "cisco-csr-1000v",<br>  "cisco-c8000v",<br>  "freebsd-13"<br>]</pre> | no |
| <a name="input_interfaces"></a> [interfaces](#input\_interfaces) | n/a | <pre>list(object({<br>    name                   = string<br>    subnet_id              = string<br>    private_ip_address     = optional(string, null)<br>    private_ipv6_address   = optional(string, null)<br>    create_public_ip       = optional(bool, false)<br>    public_ip_address_id   = optional(string, null)<br>    public_ipv6_address_id = optional(string, null)<br>  }))</pre> | n/a | yes |
| <a name="input_ip_forwarding_enabled"></a> [ip\_forwarding\_enabled](#input\_ip\_forwarding\_enabled) | enable ip forwarding | `bool` | `false` | no |
| <a name="input_location"></a> [location](#input\_location) | vnet region location | `string` | n/a | yes |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | log analytics workspace name | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | virtual machine resource name | `string` | n/a | yes |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | prefix to append before all resources | `string` | `""` | no |
| <a name="input_private_ip_trust"></a> [private\_ip\_trust](#input\_private\_ip\_trust) | optional static private trust ip of vm | `any` | `null` | no |
| <a name="input_private_ip_untrust"></a> [private\_ip\_untrust](#input\_private\_ip\_untrust) | optional static private untrust ip of vm | `any` | `null` | no |
| <a name="input_public_ip"></a> [public\_ip](#input\_public\_ip) | optional static public ip of vm | `any` | `null` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | resource group name | `any` | n/a | yes |
| <a name="input_source_image_offer"></a> [source\_image\_offer](#input\_source\_image\_offer) | source image reference offer | `string` | `"0001-com-ubuntu-server-focal"` | no |
| <a name="input_source_image_publisher"></a> [source\_image\_publisher](#input\_source\_image\_publisher) | source image reference publisher | `string` | `"Canonical"` | no |
| <a name="input_source_image_reference_library"></a> [source\_image\_reference\_library](#input\_source\_image\_reference\_library) | source image reference | `map(any)` | <pre>{<br>  "cisco-c8000v": {<br>    "offer": "cisco-c8000v",<br>    "publisher": "cisco",<br>    "sku": "17_11_01a-byol",<br>    "version": "latest"<br>  },<br>  "cisco-csr-1000v": {<br>    "offer": "cisco-csr-1000v",<br>    "publisher": "cisco",<br>    "sku": "17_3_4a-byol",<br>    "version": "latest"<br>  },<br>  "debian-10": {<br>    "offer": "debian-10",<br>    "publisher": "Debian",<br>    "sku": "10",<br>    "version": "0.20201013.422"<br>  },<br>  "freebsd-13": {<br>    "offer": "freebsd-13_1",<br>    "publisher": "thefreebsdfoundation",<br>    "sku": "13_1-release",<br>    "version": "latest"<br>  },<br>  "ubuntu-18": {<br>    "offer": "UbuntuServer",<br>    "publisher": "Canonical",<br>    "sku": "18.04-LTS",<br>    "version": "latest"<br>  },<br>  "ubuntu-20": {<br>    "offer": "0001-com-ubuntu-server-focal",<br>    "publisher": "Canonical",<br>    "sku": "20_04-lts",<br>    "version": "latest"<br>  },<br>  "ubuntu-22": {<br>    "offer": "0001-com-ubuntu-server-jammy",<br>    "publisher": "Canonical",<br>    "sku": "22_04-lts",<br>    "version": "latest"<br>  }<br>}</pre> | no |
| <a name="input_source_image_sku"></a> [source\_image\_sku](#input\_source\_image\_sku) | source image reference sku | `string` | `"20_04-lts"` | no |
| <a name="input_source_image_version"></a> [source\_image\_version](#input\_source\_image\_version) | source image reference version | `string` | `"latest"` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | sh public key data | `string` | `null` | no |
| <a name="input_storage_account"></a> [storage\_account](#input\_storage\_account) | storage account object | `any` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | tags for all hub resources | `map(any)` | `null` | no |
| <a name="input_use_vm_extension"></a> [use\_vm\_extension](#input\_use\_vm\_extension) | use virtual machine extension | `bool` | `false` | no |
| <a name="input_user_assigned_ids"></a> [user\_assigned\_ids](#input\_user\_assigned\_ids) | list of identity ids | `list(any)` | `[]` | no |
| <a name="input_vm_extension_auto_upgrade_minor_version"></a> [vm\_extension\_auto\_upgrade\_minor\_version](#input\_vm\_extension\_auto\_upgrade\_minor\_version) | vm extension settings | `bool` | `true` | no |
| <a name="input_vm_extension_publisher"></a> [vm\_extension\_publisher](#input\_vm\_extension\_publisher) | vm extension publisher | `string` | `"Microsoft.OSTCExtensions"` | no |
| <a name="input_vm_extension_settings"></a> [vm\_extension\_settings](#input\_vm\_extension\_settings) | vm extension settings | `string` | `""` | no |
| <a name="input_vm_extension_type"></a> [vm\_extension\_type](#input\_vm\_extension\_type) | vm extension type | `string` | `"CustomScriptForLinux"` | no |
| <a name="input_vm_extension_type_handler_version"></a> [vm\_extension\_type\_handler\_version](#input\_vm\_extension\_type\_handler\_version) | vm extension type | `string` | `"1.5"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | size of vm | `string` | `"Standard_B2s"` | no |
| <a name="input_zone"></a> [zone](#input\_zone) | availability zone for supported regions | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_interface_id"></a> [interface\_id](#output\_interface\_id) | n/a |
| <a name="output_interface_ids"></a> [interface\_ids](#output\_interface\_ids) | n/a |
| <a name="output_interface_name"></a> [interface\_name](#output\_interface\_name) | n/a |
| <a name="output_interface_names"></a> [interface\_names](#output\_interface\_names) | n/a |
| <a name="output_interfaces"></a> [interfaces](#output\_interfaces) | n/a |
| <a name="output_private_ip_address"></a> [private\_ip\_address](#output\_private\_ip\_address) | n/a |
| <a name="output_private_ip_addresses"></a> [private\_ip\_addresses](#output\_private\_ip\_addresses) | n/a |
| <a name="output_private_ipv6_address"></a> [private\_ipv6\_address](#output\_private\_ipv6\_address) | n/a |
| <a name="output_public_ip_address"></a> [public\_ip\_address](#output\_public\_ip\_address) | n/a |
| <a name="output_public_ipv6_address"></a> [public\_ipv6\_address](#output\_public\_ipv6\_address) | n/a |
| <a name="output_vm"></a> [vm](#output\_vm) | n/a |
<!-- END_TF_DOCS -->
