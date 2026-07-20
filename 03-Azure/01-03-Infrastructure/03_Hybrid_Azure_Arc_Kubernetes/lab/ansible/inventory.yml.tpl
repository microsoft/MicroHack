# Ansible connects via Bastion tunnels to localhost with per-VM ports.
# Run open-bastion-tunnels.sh BEFORE running the playbook.
all:
  children:
    workstations:
      hosts:
%{ for i, idx in indices ~}
        workstation-${format("%02d", idx)}:
          ansible_host: 127.0.0.1
          ansible_winrm_port: ${55986 + i}
          bastion_vm_id: ${workstation_vm_ids[i]}
          private_ip: ${workstation_ips[i]}
%{ endfor ~}
      vars:
        ansible_user: ${admin_user}
        ansible_connection: winrm
        ansible_winrm_scheme: https
        ansible_winrm_transport: basic
        ansible_winrm_server_cert_validation: ignore
