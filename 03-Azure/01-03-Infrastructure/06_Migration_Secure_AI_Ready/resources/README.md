# Deploy the Landing Zone for the Hack

Download the \*.bicep files to your local PC and follow [Solution 1](../walkthrough/challenge-01/solution-01.md).


## Quota information if multiple users deploy to the same subscription

If you have multiple users deploying to the same subscription, you need to make sure you have enough quota for the deployments.
For a single-user deployment, you should make sure to have the following quotas requested upfront:

| Quota name  | Needed quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 30  |
| Standard DSv5 Family vCPUs  | 16  |
| Standard BS Family vCPUs  | 10  |
| Public IP Addresses - Standard | 5 |

For five users who need to deploy individually to a region, make sure you have the following quotas in place:

| Quota name  | Needed quantity |
| ------------- | ------------- |
| Total Regional vCPUs  | 150  |
| Standard DSv5 Family vCPUs  | 80  |
| Standard BS Family vCPUs  | 50  |
| Public IP Addresses - Standard | 25 |

To request a quota increase, follow [Request quota increases in the Azure portal](https://learn.microsoft.com/en-us/azure/quotas/quickstart-increase-quota-portal).
