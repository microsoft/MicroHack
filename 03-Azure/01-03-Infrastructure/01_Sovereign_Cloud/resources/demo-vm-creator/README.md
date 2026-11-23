# LocalBox guide has moved

Choose [hosted-event setup](../hosted-events/readme.md) or [manual setup](../manual-setup/readme.md). Hosted Console events automatically deploy, prepare and infrastructure-test LocalBox. Manual organizers run the common [LocalBox preparation](../localbox/readme.md) themselves; hosted leads use it only for deliberate recovery, never concurrently with the hosted job.

The manual deployment script is now [manual-setup/localbox/deploy-localbox.ps1](../manual-setup/localbox/deploy-localbox.ps1). The Console continues to use the existing labautomation hook.

## Step 6: Test the Environment

For hosted delivery, inspect the automated LocalBox health results; for manual delivery, run the [Pester health checks](../tests/readme.md). In either case, complete the [participant VM guest-management, Defender and Update Manager readiness exercise](../localbox/manual-preparation.md#step-6-test-the-environment), including actual participant access and Defender cloud reporting. This page preserves existing challenge links.