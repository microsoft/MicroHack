# Deploy the Landing Zone for the Micro Hack

Clone the GitHub repository using Azure Cloud Shell and deploy .\bicep\main.bicep file. [Solution 1](../walkthrough/challenge-1/solution.md)


## Quota Information if multiple Users Deploy to the same subscription

If you have multiple users deploying to the same subscription you need to make sure you have enough quota for the deployments.
For 1 User deployment you should make sure to have the following quotas requested upfront:

| Quota name  | needed Quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 30  |
| Standard DSv5 Family vCPUs  | 16  |
| Standard BS Family vCPUs  | 10  |
| Public IP Addresses - Standard | 5 |

That means for 5 Users that need to deploy individually to a Region you need to make sure you have the following quotas in place:

| Quota name  | needed Quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 150  |
| Standard DSv5 Family vCPUs  | 80  |
| Standard BS Family vCPUs  | 50  |
| Public IP Addresses - Standard | 25 |

To request the quota please follow: https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal
