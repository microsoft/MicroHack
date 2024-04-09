# Challenge 4: Integrate Azure Front Door

[Previous Challenge](./03-GitHub-Actions.md) - **[Home](../README.md)**

## Introduction

To be able to use the full potential of Azure for our new application, we want to add Azure Front Door to our environment. Front Door enables you to define, manage, and monitor the global routing for your web traffic by optimizing for top-tier end-user perfomrance and reliability. It includes a range of traffic-routing methods and backend health monitoring options. The health monitoring options include:

- reports on how your Azure Front Door behaves along with associated Web Application Firewall metrics,
- metrics to help monitor Azure Front Door in real-time to track, troubleshoot, and debug issues and
- protocols to help you track, monitor, and debug your Front Door. Acces logs have information about every request that Front Door receives, Activity logs provide visibility into the operations done, Health Probe logs provide logs for failed probe to origin and Web Application Firewall logs give detailed information of requests that gets logged through detection or prevention mode of a Front door endpoint.

## Challenge

- Add Azure Front Door to your platform
- Use Azure for monitoring Access reports
- Use Azure Front Door to monitor Metrics
- Use Azure Front Door to monitor protocols

## Success Criteria

- Front Door used in the environment
- Frontend Accesss through Front Door url
- Reports for "Traffic by Domain" within the last week available
- Metrics available
- FrontDoorAccessLog, FrontDoorHealthProbeLog and FrontDoorApplicationFirewallLog accessable

## Learning Resources

- [Azure Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)
- [Azure Front Door (classic)](https://learn.microsoft.com/en-us/azure/frontdoor/classic-overview)
- [Implementing Front Door](https://learn.microsoft.com/en-us/azure/frontdoor/quickstart-create-front-door)

## Solution - Spoilerwarning

Challenge 4: [Integrate Azure Front Door](../Solutionguide/04-FrontDoor-solution.md)

# Finish

Congratulations! You finished the MicroHack Serverless Microservices. We hope you had the chance to learn about Microservices and how to implement them using Azure. If you want to give feedback please dont hesitate to open an Issue on the repository or get in touch with one of us directly.

Thank you for investing the time and see you next time!
