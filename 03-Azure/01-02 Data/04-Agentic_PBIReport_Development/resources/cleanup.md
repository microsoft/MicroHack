# Cleanup responsibilities

Follow the organizer's approved retention decision. Export only sanitized source;
keep operational evidence private and delete credentials/tokens from local logs.
Participants close agent sessions and sign out of shared browsers. The workspace
owner deletes their own Fabric workspace only when instructed and verifies deletion.
Fabric workspaces are not deleted by deleting an Azure VM resource group.

The organizer verifies all workspaces/OneLake data are removed or retained with an
owner, removes participant VMs/disks/network resources, and pauses/removes the
shared F16 only after every participant is finished. Deallocate is not disk deletion;
capacity pause does not remove stored data or all possible charges. Record actual
Azure/Fabric cleanup and residual costs. Platform/license administrators handle
seat/account recovery under their retention policy, not a participant script.
The shared Azure resource group also contains Bastion, NAT, public endpoint IPs
and the VNet. Remove those shared resources only after all participant VMs are
finished and retention is resolved; deleting VMs or pausing F16 does not stop
their charges. Remove participant resources before their shared subnets/network.

Complete the [release evidence ledger](release-gates.md) privately;
only an independent reviewer can issue an event-readiness verdict.
