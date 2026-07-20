# Deploy the Landing Zone for the Hack

Download the \*.bicep files to your local PC and follow [Solution 1](../walkthrough/challenge-01/solution-01.md).

The deployment defaults to downloading automation and demo-page assets from `microsoft/MicroHack` on the `main` branch. To test a fork before merge, check out that fork branch locally and pass the existing `githubAccount` and `githubBranch` parameters as described in Solution 1. The selected branch must contain the same Hack resource paths.


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
