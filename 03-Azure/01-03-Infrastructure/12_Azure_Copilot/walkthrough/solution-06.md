# Walkthrough Challenge 6 - Troubleshooting Agent

**[Home](../Readme.md)** - [Previous Challenge Solution](solution-05.md) - [Next Challenge Solution](solution-07.md)

**Estimated Duration:** 45 minutes

> 💡 **Objective:** Learn to diagnose and resolve Azure resource issues using the Troubleshooting Agent in Azure Copilot — from VM connectivity problems to AKS cluster issues and support request creation.

---

## Task 1: Troubleshoot VM Connectivity

### Steps

1. **Open Azure Copilot** and **enable agent mode**
2. **Enter the prompt:** _"I can't connect to my VM, can you help me troubleshoot?"_
3. **Select the VM** when Azure Copilot prompts you (or provide: "The VM is `vm-copilot-broken` in `rg-copilot-<suffix>-ch05`")

### Expected Diagnostic Process

Azure Copilot runs through these checks automatically:

```text
🔍 Diagnostic Checks for vm-copilot-broken:

1. ✅ VM Power State: Running
   → The VM is currently powered on

2. ⚠️ Network Security Group Rules:
   → NSG 'nsg-copilot-broken' is attached to the subnet
   → Inbound SSH (port 22): DENIED
   → Inbound RDP (port 3389): DENIED
   → All inbound traffic: DENIED
   → ⚠️ NSG is blocking all connectivity to this VM

3. ✅ Public IP: Assigned
   → Public IP: 52.xxx.xxx.xxx

4. ✅ VM Agent Status: Running and Ready
   → Agent version: 2.7.41491.1034

5. ✅ OS Disk: Healthy
   → No disk health issues detected

6. ✅ Platform Health: No known issues
   → No service incidents affecting this VM's region
```

### Common Findings and Fixes

| Finding                    | Fix Type  | Action                      |
| -------------------------- | --------- | --------------------------- |
| VM is stopped/deallocated  | One-click | "Start VM" button offered   |
| NSG blocking all traffic   | Guided    | Steps to modify NSG rules   |
| No public IP assigned      | Guided    | Steps to assign public IP   |
| VM agent not ready         | Guided    | Steps to troubleshoot agent |
| OS-level firewall blocking | Guided    | Steps to check OS firewall  |

### Answer

The automatic diagnostic checks mirror what an experienced engineer would do manually:

1. Check if the VM is running
2. Check network path (NSG, firewall, public IP)
3. Check VM agent health
4. Check for platform issues

**Key difference:** The agent completes all checks in **seconds** vs. **10-15 minutes** of manual portal navigation.

---

## Task 2: Troubleshoot a Database Connection Issue

### Steps

1. **Start a new conversation** with agent mode enabled
2. **Enter:** _"I'm trying to connect to my Azure Cosmos DB (NoSQL API) from my local development machine, but I keep getting a timeout. What should I do?"_
3. **Select the Cosmos DB account** if prompted, or work with guidance

### Expected Diagnostic Flow

```text
🔍 Investigating Cosmos DB (NoSQL API) Connection Timeout

Step 1: Connection Configuration Check
→ Verify your connection string includes:
  - Endpoint: https://<account-name>.documents.azure.com:443/
  - Authorization Key: Primary or Secondary key
  - SSL/TLS: Enabled (required for Cosmos DB)

Step 2: Firewall Rules
→ Checking Cosmos DB firewall configuration...
→ ⚠️ Firewall is enabled with IP restrictions
→ Your current IP (203.0.113.xx) is NOT in the allowed list

Root Cause: Your local machine's IP address is not whitelisted
in the Cosmos DB firewall rules.

Remediation Steps:
1. Navigate to your Cosmos DB account → Networking
2. Under "Firewall", add your IP address: 203.0.113.xx
3. Or click "Add my current IP"
4. Save the changes (takes 1-2 minutes to propagate)
5. Retry the connection

Additional checks if the issue persists:
- Verify SSL/TLS certificate is trusted
- Ensure port 443 is not blocked by your local firewall
- Check if VPN is routing traffic through a different IP
```

### Follow-Up Questions

**"Could this be a firewall issue?"**

> Azure Copilot confirms or denies based on the Cosmos DB firewall configuration it examined.

**"How do I check if my IP is whitelisted?"**

> Azure Copilot provides the portal navigation path: Cosmos DB → Networking → Firewall and virtual networks.

**"What are the common causes of Cosmos DB timeouts?"**

> A comprehensive list:
>
> 1. IP not whitelisted in firewall
> 2. Incorrect endpoint URL or port
> 3. SSL/TLS not configured
> 4. RU throttling (429 errors)
> 5. Region unavailability
> 6. Large partition key causing hot partitions

### Answer

Even when the agent can't directly access a resource (e.g., testing from your local machine), it:

- **Checks the server-side configuration** (firewall rules, networking)
- **Provides client-side guidance** (connection string format, port numbers, SSL requirements)
- **Offers a systematic troubleshooting approach** — eliminating causes one by one

---

## Task 3: Troubleshoot AKS Cluster Issues

### Steps

**Prompt 1:** _"Investigate the health of my pods."_

> **Expected response:**
>
> ```text
> 🔍 Pod Health Investigation for aks-contoso
>
> Cluster Status: Running
> Node Pool: agentpool (3 nodes)
>
> Pod Status Summary:
> ✅ Running: 12
> ⚠️ Pending: 2
> ❌ CrashLoopBackOff: 1
> ❌ ImagePullBackOff: 1
>
> Issues Found:
>
> 1. Pod 'api-service-7d8f9' — CrashLoopBackOff
>    Container exits with code 1 after 3 seconds
>    Last log: "Error: Cannot connect to database at postgres:5432"
>    → Root Cause: Database connection string misconfigured
>    → Fix: Update the configmap or secret with correct DB connection details
>
> 2. Pod 'frontend-abc12' — ImagePullBackOff
>    Image: contoso.azurecr.io/frontend:v2.1
>    Error: "unauthorized: authentication required"
>    → Root Cause: AKS doesn't have pull access to the ACR
>    → Fix: Attach ACR to AKS cluster using:
>       az aks update -n aks-contoso -g rg-copilot-<suffix>-ch05 --attach-acr contosoacr
> ```

**Prompt 2:** _"Investigate networking issues causing pod connectivity failures."_

> **Expected:** Network policy analysis, DNS resolution checks, service endpoint verification.

**Prompt 3:** _"Identify reasons for high CPU or memory usage in my AKS cluster."_

> **Expected:** Node-level and pod-level resource analysis with optimization recommendations.

**Prompt 4:** _"My AKS cluster nodes are in NotReady state and I've tried restarting them. What else can I do?"_

> **Expected:** When self-remediation is exhausted:
>
> ```text
> Advanced Troubleshooting for NotReady Nodes:
>
> 1. Check kubelet logs: kubectl logs -n kube-system <kubelet-pod>
> 2. Verify node conditions: kubectl describe node <node-name>
> 3. Check for Azure platform issues in Service Health
> 4. Review node pool scaling events
>
> If these steps don't resolve the issue:
> → I can help you create a support request with all diagnostic
>    details pre-populated for the Azure support team.
>
> Would you like me to create a support request?
> ```

### Answer

When the agent can't auto-remediate (common for AKS):

1. **Provides detailed diagnostic commands** you can run
2. **Explains the root cause** even if it can't fix it
3. **Offers to create a support request** as an escalation path
4. **Pre-populates the support ticket** with diagnostic data collected

---

## Task 4: Experience One-Click Fixes

### Creating a Testable Scenario

**Simple test: Stop a VM, then ask for connectivity help**

1. Stop the VM: Navigate to `vm-copilot-broken` → **Stop**
2. Wait for it to fully deallocate
3. Open Azure Copilot (agent mode) and ask:
   > _"My VM vm-copilot-broken isn't responding. Help me troubleshoot."_

### Expected One-Click Fix

```text
🔍 Diagnostic Results for vm-copilot-broken:

❌ VM Power State: Stopped (Deallocated)
   The VM is currently powered off, which is why it's not
   responding to connections.

🔧 Quick Fix Available:
   [▶️ Start VM]  ← One-click fix button

   Clicking this will start your VM. The VM typically takes
   1-3 minutes to boot and become accessible.

   Do you want to proceed?
```

After clicking the fix:

- Azure Copilot shows a **confirmation prompt**
- You **confirm** the action
- The VM starts
- Azure Copilot confirms it's running

### Types of Issues with One-Click Fixes

| Issue                       | One-Click Fix              |
| --------------------------- | -------------------------- |
| VM stopped/deallocated      | Start VM                   |
| Arc server extension failed | Reinstall extension        |
| NSG missing critical rule   | Add the required rule      |
| Container restarted         | Restart container instance |

### When One-Click Isn't Available

For more complex issues, Azure Copilot provides:

- **Numbered steps** with portal navigation
- **CLI/PowerShell commands** to execute
- **Configuration changes** to make
- **Links to documentation** for deeper understanding

### Answer

One-click fixes are available for **common, well-understood issues** with clear, safe remediation actions. Complex issues, issues affecting multiple resources, or issues requiring careful planning (like AKS node problems) get detailed instructions instead.

---

## Task 5: Create a Support Request

### Steps

1. **Enter the prompt:** _"Create a support request."_

   Or with more context:

   > _"My application is experiencing intermittent failures that I can't diagnose. Can you create a support request?"_

2. **Azure Copilot gathers information:**

   ```text
   I'll help you create a support request. Let me gather some details:

   1. Which resource is affected?
      → [Resource picker appears]

   2. What type of issue are you experiencing?
      → Connectivity / Performance / Data loss / Configuration / Other

   3. When did the issue start?
      → [Date/time input]

   4. What is the business impact?
      → Critical / High / Medium / Low
   ```

3. **Review the pre-populated request:**

   ```text
   Support Request Preview:

   Title: Intermittent application failures on webapp-contoso
   Service: App Service (Web Apps)
   Resource: webapp-contoso
   Severity: B - Moderate business impact

   Description:
   The application hosted on Azure App Service is experiencing
   intermittent HTTP 500 errors. Diagnostic checks performed:
   - App Service status: Running
   - Recent deployments: Last deployment 3 days ago
   - Application Insights: Shows increased exception rate
   - Platform health: No known issues

   Previous troubleshooting steps:
   - Restarted the application
   - Reviewed application logs
   - Checked connection strings

   [Submit Request]  [Edit Details]  [Cancel]
   ```

4. **Submit or cancel** as appropriate

### Answer

Azure Copilot pre-populating the support request improves the experience by:

- **Including diagnostic data** — Support engineers see the checks already performed
- **Accurate categorization** — The issue is routed to the right team
- **Detailed context** — Reduces back-and-forth with the support team
- **Time savings** — Minutes instead of filling out forms and navigating dropdowns

---

## Summary

| Skill                               | Status |
| ----------------------------------- | ------ |
| Troubleshoot VM connectivity        | ✅     |
| Diagnose database connection issues | ✅     |
| Investigate AKS pod/node problems   | ✅     |
| Use one-click fixes                 | ✅     |
| Create support requests             | ✅     |
| Understand escalation paths         | ✅     |

You successfully completed challenge 6! 🚀🚀🚀
