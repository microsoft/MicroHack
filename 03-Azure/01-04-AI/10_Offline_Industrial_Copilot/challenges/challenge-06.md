# Challenge 6 - Cut the cord

[Previous Challenge](challenge-05.md) - **[Home](../Readme.md)** - [Finish](finish.md)

## Goal

**Prove** that the complete copilot works with no internet connection.

## Actions

* Run your complete copilot once **while connected** and write down how long each kind of question takes: a procedure question, a machine status, a fault prediction, and a ticket.
* **Get ready before you disconnect.** Make sure the Foundry Local service is running and your models are loaded, and ask one question of each kind so everything is warm. **Do not restart the service while you are offline.** Find out why: what does the service need when it starts?
* Disconnect the device from the internet. Choose a way that matches your setup:
  * Laptop: turn off Wi-Fi, unplug the cable, or block outbound traffic with the firewall.
  * VM: block outbound internet traffic with a network security group rule. Keep a way to reach the VM.
* Check that you really are offline.
* Run the same scenario again: answer from an SOP with a citation, call the tools, use the ONNX model, and create a ticket.
* Record the latency of each step while offline.
* Find out whether **anything** still needs the internet. Look at what your copilot does at start-up, and what the Foundry Local service does.
* Discuss what must still happen when the device is back online: updates, new models, syncing tickets, monitoring.
* **Stretch:** make your copilot survive a restart of the model service while the device is offline. The Foundry Local SDK (`pip install foundry-local-sdk`) can start models from your local cache. What does it need that the `foundry` service gets from the internet?

## Success criteria

* Every capability from challenges 3 to 5 works while the device is disconnected.
* You recorded the latency of each step, connected and disconnected, and can compare them.
* You can name at least two things that still need the cloud, and say when they would happen.

## Learning resources

* [Foundry Local architecture](https://learn.microsoft.com/azure/foundry-local/concepts/foundry-local-architecture)
* [Network security groups](https://learn.microsoft.com/azure/virtual-network/network-security-groups-overview)
* [Windows Firewall rules with PowerShell](https://learn.microsoft.com/powershell/module/netsecurity/new-netfirewallrule)
