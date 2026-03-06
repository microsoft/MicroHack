# Challenge 6 - Azure NetApp Files Backup

[Previous Challenge Solution](challenge-05.md) - **[Home](../Readme.md)** - [Next Challenge Solution](challenge-07.md)

## Goal

The goal of this challenge is to configure Azure NetApp Files Backup to protect data used in an Azure Virtual Desktop environment.
You will ensure that Azure NetApp Files volumes are covered by a backup configuration that supports data protection and recovery requirements.

## Actions

* Enable Azure NetApp Files Backup in the target region
* Create or use an existing backup vault
* Configure a backup policy for Azure NetApp Files volumes
* Assign the backup policy to the relevant Azure NetApp Files volume
* Verify that backups are being created successfully

## Success criteria

This challenge is completed successfully when:

* Azure NetApp Files Backup is enabled
* A backup vault exists and is available
* A backup policy is configured and assigned to an Azure NetApp Files volume
* Backup jobs are visible and complete successfully
* The volume is protected according to the configured policy

## Learning resources

* [Azure NetApp Files Backup overview](https://learn.microsoft.com/azure/azure-netapp-files/backup-introduction)
* [Configure Azure NetApp Files Backup](https://learn.microsoft.com/azure/azure-netapp-files/backup-configure)
* [Azure NetApp Files data protection](https://learn.microsoft.com/azure/azure-netapp-files/azure-netapp-files-data-protection)

