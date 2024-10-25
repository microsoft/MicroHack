# Microhack - Intro To Oracle DB Migration to Azure

## Important Notice

This project is currently under development and is subject to change until the first official release, which is expected by the end of 2024. Please note that all content, including instructions and resources, may be updated or modified as the project progresses.


## Introduction

This intro level microhack (hackathon) will help you get hands-on experience migrating Oracle databases from on-premises to different Azure Services.

## Learning Objectives
In this microhack you will solve a common challenge for companies migrating to the cloud: migrating Oracle databases to Azure. The application using the database is a sample e-commerce [application](https://github.com/pzinsta/pizzeria) written in JavaScript. It will be configured to use Oracle Database Express Edition [Oracle XE]. 

The participants will learn how to:

1. Perform a pre-migration assessment of the databases looking at size, database engine type, database version, etc.
1. Use offline tools to copy the databases to Azure OSS databases
1. Use the Azure Database Migration Service to perform an online migration (if applicable)
1. Do cutover and validation to ensure the application is working properly with the new configuration
1. Use a private endpoint for Azure OSS databases instead of a public IP address for the database
1. Configure a read replica for the Azure OSS databases

## Challenges
- Challenge 0: **[Pre-requisites - Setup Environment and Prerequisites!](Student/00-prereqs.md)**
   - Prepare your environment to run the sample application
- Challenge 1: **[Discovery and assessment](Student/01-discovery.md)**
   - Discover and assess the application's PostgreSQL/MySQL/Oracle databases
- Challenge 2: Oracle to IaaS migration
- Challenge 3: Oracle to PaaS migration
- Challenge 4: Oracle to Azure OCI migration
- Challenge 5: Oracle to Oracle Database on Azure migration

## Prerequisites

- Access to an Azure subscription with Owner access
   - If you don't have one, [Sign Up for Azure HERE](https://azure.microsoft.com/en-us/free/)
   - Familiarity with Azure Cloud Shell
- [**Visual Studio Code**](https://code.visualstudio.com/) (optional)

## Repository Contents
- `../Coach`
  - [Lecture presentation](Coach/OSS-DB-What-the-Hack-Lecture.pptx?raw=true) with short presentations to introduce each challenge
  - Example solutions and coach tips to the challenges (If you're a student, don't cheat yourself out of an education!)
- `../Student/Resources`
   - Pizzeria application environment setup

## Contributors

