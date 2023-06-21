# AVS Storage Policy

[Previous Challenge](./12-AVS-ANF-Datastores.md) - **[Home](../Readme.md)** - [Next Challenge](./14-AVS-Placement-Policy.md)

## Introduction

VMware vSAN storage policies define storage requirements for your virtual machines (VMs). These policies guarantee the required level of service for your VMs because they determine how storage is allocated to the VM. Each VM deployed to a vSAN datastore is assigned at least one VM storage policy.

You can assign a VM storage policy in an initial deployment of a VM or when you do other VM operations, such as cloning or migrating. Post-deployment cloudadmin users or equivalent roles can't change the default storage policy for a VM. However, VM storage policy per disk changes is permitted.

The Run command lets authorized users change the default or existing VM storage policy to an available policy for a VM post-deployment. There are no changes made on the disk-level VM storage policy. You can always change the disk level VM storage policy as per your requirements.

## Challenge 

## Success Criteria

## Learning resources