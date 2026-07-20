# Walkthrough Challenge 4 - Optimization Agent

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-03.md) - [Next Challenge Solution](solution-05.md)

**Estimated Duration:** 45 minutes

> 💡 **Objective:** Learn to optimize Azure resources for cost using the Optimization Agent in Azure Copilot — from discovering savings opportunities to generating optimization scripts.

---

## Task 1: Discover Cost-Saving Opportunities

### Steps

1. **Open Azure Copilot** and **enable agent mode**
2. **Find your subscription ID:**
   - Navigate to **Subscriptions** in the Azure portal
   - Copy the **Subscription ID** (GUID format: `aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e`)
3. **Enter the prompt:**
   > _"Show me the top five cost-saving opportunities for subscription `aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e`"_

### Expected Response

Azure Copilot returns a list like:

```text
Top 5 Cost-Saving Opportunities for Subscription "Contoso Production"

1. VM: vm-copilot-oversized (Standard_D4s_v3 → Standard_D2s_v3)
   💰 Estimated savings: $120/month
   📊 Avg CPU utilization: 12%

2. VM: vm-batch-worker (Standard_E8s_v5 → Standard_E4s_v5)
   💰 Estimated savings: $280/month
   📊 Avg CPU utilization: 8%, Avg memory: 15%

3. VMSS: vmss-api-tier (4 instances → 2 instances, with autoscale)
   💰 Estimated savings: $350/month
   📊 Avg scale set utilization: 22%

4. VM: vm-dev-test01 (Always running → Shut down off-hours)
   💰 Estimated savings: $180/month
   📊 Zero usage 6PM-8AM and weekends

5. VM: vm-sql-prod (Standard_D8s_v3 → Standard_D4s_v3)
   💰 Estimated savings: $240/month
   📊 Avg CPU: 15%, Avg memory: 30%

💵 Total potential savings: ~$1,170/month (~$14,040/year)
```

### Broader Summary

**Prompt:** _"Summarize total potential monthly savings from all active Azure Advisor cost recommendations, grouped by category (VM rightsizing, reserved instances, idle resources)."_

> - Azure Copilot typically highlights the biggest areas to inspect first, such as oversized compute, idle resources, reservations, or storage lifecycle opportunities.
> - The response may be based on spend patterns rather than explicit Azure Advisor items.
> - A short prioritized list of savings themes is sufficient for this step.
> - Treat the answer as triage guidance rather than a finalized optimization plan.

### Answer

The Optimization Agent identifies savings in categories like:

- **VM rightsizing** — Reducing overprovisioned VM SKUs
- **Shutdown schedules** — Stopping dev/test VMs during off-hours
- **Scale set optimization** — Right-sizing VMSS instance counts
- **Reserved instance opportunities** — Switching to reserved pricing for steady-state workloads

---

## Task 2: Deep-Dive into a Specific Recommendation

### Steps

**Prompt 1:** _"Explain the recommendation for vm-copilot-oversized."_

> 💡 **Multi-turn note:** Copilot may first ask a clarifying question such as _"Which time range should I analyze?"_. If so, reply with **"Use the last 30 days."** and Copilot will continue with the full recommendation.

> **Expected response:**
>
> ```text
> Recommendation Details: vm-copilot-oversized
>
> Current Configuration:
>   SKU: Standard_D4s_v3 (4 vCPUs, 16 GB RAM)
>   Monthly cost: ~$280
>
> Recommended Configuration:
>   SKU: Standard_D2s_v3 (2 vCPUs, 8 GB RAM)
>   Monthly cost: ~$160
>
> Why this recommendation:
>   - Over the past 30 days, average CPU utilization is 12% (peak: 45%)
>   - Average memory utilization is 22% (peak: 58%)
>   - The workload fits comfortably within the D2s_v3 capacity
>
> Performance Impact:
>   - Minimal — current peak usage is well within D2s_v3 limits
>   - CPU and memory headroom remains adequate for burst scenarios
>
> Savings: $120/month ($1,440/year)
> ```

**Prompt 2:** _"Is there an alternate recommendation for vm-copilot-oversized?"_

> **Expected response:**
>
> ```text
> Alternative Recommendation: vm-copilot-oversized
>
> Option A (Primary): Standard_D4s_v3 → Standard_D2s_v3
>   Savings: $120/month | Performance impact: Low
>
> Option B (Alternative): Standard_D4s_v3 → Standard_B2s
>   Savings: $230/month | Performance impact: Medium
>   Note: B-series uses burstable credits; suitable only if
>   workload has low baseline with occasional spikes
>
> Option C (Alternative): Keep D4s_v3 + 1-year Reserved Instance
>   Savings: $95/month | Performance impact: None
>   Note: Requires 1-year commitment
>
> Recommendation: Option A balances savings with reliability
> ```

### Answer

The agent provides **excellent detail** for informed decisions:

- Current and recommended configurations side-by-side
- Utilization metrics that justify the recommendation
- Performance impact assessment
- Multiple alternatives with explicit trade-offs
- A clear recommendation among the options

---

## Task 3: Visualize Optimization Impact

### Steps

**Prompt:** _"Show me a chart of the expected results of applying the recommendation for vm-copilot-oversized."_

### Expected Chart

Azure Copilot generates a visual chart showing:

```text
📊 Chart: VM Rightsizing Impact — vm-copilot-oversized

[Bar Chart showing:]
├── Current Cost:     ████████████████ $280/month
├── Recommended Cost: ████████████     $160/month
└── Savings:          ████             $120/month (43%)

[Line Chart showing:]
├── CPU Utilization:    12% avg → Well within D2s_v3 capacity (2 vCPUs)
└── Memory Utilization: 22% avg → Well within D2s_v3 capacity (8 GB)
```

### Subscription Summary

**Prompt:** _"Give me a subscription-level optimization summary: total potential monthly savings, breakdown by resource type (VMs, storage, databases), and the top 3 recommendations by impact."_

> - Azure Copilot summarizes spend or optimization opportunities by service family such as compute, storage, or databases.
> - The answer highlights likely savings themes and top cost drivers, even if it does not quantify every action precisely.
> - A concise executive summary is enough; the response does not need to enumerate every recommendation in the subscription.
> - Participants should use this as a briefing view before drilling into one specific optimization area.

### Answer

Visual charts are **highly valuable for stakeholder communication**:

- Executives see the financial impact at a glance
- Engineering teams see the performance headroom
- FinOps teams see the savings breakdown by category
- Charts can be exported or screenshot for presentations

---

## Task 4: Generate Optimization Scripts

### PowerShell Script

**Prompt:** _"Generate a PowerShell script to apply the recommended optimizations for vm-copilot-oversized."_

> **Expected response:**
>
> ```powershell
> # Resize VM: vm-copilot-oversized
> # From: Standard_D4s_v3 → To: Standard_D2s_v3
> # Estimated savings: $120/month
> #
> # IMPORTANT: This will cause a brief downtime as the VM is
> # deallocated and resized. Plan a maintenance window.
>
> $resourceGroupName = "rg-copilot-<suffix>-ch03"
> $vmName = "vm-copilot-oversized"
> $newSize = "Standard_D2s_v3"
>
> # Step 1: Stop (deallocate) the VM
> Write-Host "Stopping VM $vmName..."
> Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
>
> # Step 2: Resize the VM
> Write-Host "Resizing VM to $newSize..."
> $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
> $vm.HardwareProfile.VmSize = $newSize
> Update-AzVM -VM $vm -ResourceGroupName $resourceGroupName
>
> # Step 3: Start the VM
> Write-Host "Starting VM $vmName..."
> Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
>
> Write-Host "VM resized successfully to $newSize"
> ```

### Azure CLI Script

**Prompt:** _"Now generate the equivalent Azure CLI (bash) script to resize `vm-copilot-oversized` in `rg-copilot-<suffix>-ch03` from Standard_D4s_v3 to Standard_D2s_v3 (deallocate, resize, start)."_

> - Azure Copilot returns an Azure CLI template for deallocating, resizing, and restarting a VM.
> - The response includes placeholders rather than assuming a live recommendation context was preserved.
> - Copilot may also include subscription-selection or authentication commands at the top.
> - Participants should expect a starter template that still needs final SKU and resource validation.

### Answer

The generated scripts are **largely ready to execute** but you should:

- ✅ **Verify** the resource group name and VM name
- ✅ **Review** the target SKU (confirm it matches the recommendation)
- ✅ **Plan a maintenance window** (VM resize requires deallocation = downtime)
- ✅ **Test in a non-production environment first** if possible
- ✅ **Notify stakeholders** about the planned downtime

---

## Task 5: Explore Optimization from Different Entry Points

### Entry Point 1: Azure Advisor

1. Navigate to **Azure Advisor** → **Cost** tab
2. Browse the cost recommendations list
3. Find a VM recommendation
4. Click the **"Optimize"** button next to the resource name
5. This opens an Azure Copilot conversation pre-loaded with the recommendation context

### Entry Point 2: Operations Center (Preview)

1. Navigate to **Operations Center** (if available in your portal)
2. View the recommendations dashboard
3. Click **"Optimize with Copilot"** next to a recommendation
4. Azure Copilot opens with the recommendation context

### Entry Point 3: Direct ARM Resource URI

**Prompt:**

> _"Show me cost saving recommendations for `/subscriptions/{YOUR_SUBSCRIPTION_ID}/resourcegroups/rg-copilot-<suffix>-ch03/providers/microsoft.compute/virtualmachines/vm-copilot-oversized`"_

**Advantage:** Precise targeting when you know exactly which resource to optimize.

### Answer

| Entry Point           | Best For                               | Convenience |
| --------------------- | -------------------------------------- | ----------- |
| **Copilot Chat**      | Browsing multiple recommendations      | ⭐⭐⭐ High |
| **Azure Advisor**     | Starting from known recommendations    | ⭐⭐⭐ High |
| **Operations Center** | Dashboard-driven optimization workflow | ⭐⭐ Medium |
| **Resource URI**      | Targeting a specific known resource    | ⭐⭐ Medium |

For daily workflow, **Azure Advisor → Optimize** is typically the most convenient entry point, since it combines the Advisor's recommendation visibility with Copilot's conversational depth.

---

## Summary

| Skill                            | Status |
| -------------------------------- | ------ |
| Query cost-saving opportunities  | ✅     |
| Explore detailed recommendations | ✅     |
| Compare alternative options      | ✅     |
| Review optimization charts       | ✅     |
| Generate PowerShell scripts      | ✅     |
| Generate CLI scripts             | ✅     |
| Use multiple entry points        | ✅     |

You successfully completed challenge 4! 🚀🚀🚀
