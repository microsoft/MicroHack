# Walkthrough Challenge 0 - Understand the Disaster Recovery terms and define a strategy




Duration: 20 minutes

## Prerequisites

Please ensure that you successfully verified the [General prerequisits](../../Readme.md#general-prerequisites) before continuing with this challenge.

### **Task 1: Write down the first 3 steps you would go for if your company got attacked by ransomware**

💡 The first three steps often depend on the employee's perspective. Are you an IT leader, CIO, CEO, or just can't work with you systems you are using on a daily basis?

* An employee's perspective
  * In order to be prepared in an emergency, it is normal that employees are informed at regular intervals about an emergency plan and there are also exercises for such emergencies at predefined intervals. If, for example, an employee is the victim of a ransomware attack, he should be informed about any necessary steps through previous exercises.

* A CISO´s perspective 
  * The CISO plays a very special role and should be informed at all times about such incidents. In order to ensure this, he should always know how to react in an emergency and also ensure together with the IT manager that teams are informed and trained about regular coordination and emergency exercises. 

* CEO perspective 
  * In order to keep the damage of any incidents / emergencies as low as possible, appropriate requirements should be defined to enable the C-Suite to act as a role model in case of a disaster. Such as highly business-critical applications that always have to run and on which the focus should be in the event of an error in order to protect the company from image loss or complete standstill. It should be clearly defined at the highest level which requirements for availability a company can and must guarantee and, above all, it must be ensured that the management regularly demands them within the framework of business continuity management.

💥 **Here are the first three general steps that are typically happen:** 
1. Everybody struggles with finding the right person and process for triggering the disaster recovery & Business continuity plan 
2. If somebody finds the plan, the first three actions for the reaction are not valid anymore because of changes in the org structure 
3. Do not sress to much we have a backup and the availability requirements are defined on Hypervisor and Storage level - let´s start the failover to the 2nd Datacenter and the users are able to work again in half an hour or so

🔑 **Key to a successful strategy in case of a disaster**
- The key to success is not a technical consideration of the topic, but a clear demarcation of responsibilities, requirements and true success is only guaranteed if you test regularly according to the previously defined requirements.

### **Task 2: Think about if you every participated in a business continuity test scenario**

Here it is only a matter of dedicating oneself to the topic and considering whether the emergency plan has ever been tested in the company and who is part of it. It can also be considered whether appropriate measures in case of success or failure were derived to increase the quality next time.

Ask yourself the questions: 
1. Can i take a active part in the optimization process from the emergency plan? 
2. Whom should i involve? 
3. Do i have feedback for application owners for the applications i am working with? 
4. When was the last succesful failover in my organization? 
5. Ask internally when the next failover is planned to test the disaster plan? 

### **Task 3: Put yourself in the position of an application owner and define the necessary steps to make sure your application stays available in case of a disaster**

Here is a small outlook on which topics you should deal with or at least work closely with IT to sharpen the requirements and be prepared in case of errors.

    1. Test regulary 
    2. Test for resiliency 
    3. Design a backup strategy 
    4. Design a disaster recovery strategy 
    5. Codify steps to failover and fallback 
    6. Plan for regional failures 
    7. Implement a retry logic 
    8. Configure test and health probes 
    9. Segregate read and write interfaces 

* [Checklist Testing for reliability](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/test-checklist)
* [Resiliency testing](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/testing)
* [Backup and disaster recovery plan](https://learn.microsoft.com/en-us/azure/architecture/framework/resiliency/backup-and-recovery)

### Task 4: Who defines the requirements for Business Continuity and what are the necessary KPI´s for an application to reach a good SLA in terms of availability?

- Different categories that are often seen as the same 
- There is a big difference and in most of the infrastructure of traditional it departments there is a 100% mirror from hardware over two datacenters
  - The 100% mirroring of the hardware ensures that all applications have a fully redundant setup, but in just a few cases this is needed
  - According to experience, however, only 10-20% of applications really need a classification in Highly Business Critical, the rest are often grouped into Moderate, Low or even just Backup & Restore.

![image](/03-Azure/01-03-Infrastructure/04_BCDR_Azure_Native/img/DifferentTerms.png)

![image](/03-Azure/01-03-Infrastructure/04_BCDR_Azure_Native/walkthrough/challenge-0/img/DR_Tier_Levels.png)



### Task 5: Plan the different geographic regions you need to use for reaching the highest availability SLA (can also include your datacenter locations)

![image](/03-Azure/01-03-Infrastructure/04_BCDR_Azure_Native/walkthrough/challenge-0/img/Customerneeds_RPO_RTO.png)

You successfully completed challenge 0! 🚀🚀🚀

 **[Home](../../Readme.md)** - [Next Challenge Solution](../challenge-1/solution.md)