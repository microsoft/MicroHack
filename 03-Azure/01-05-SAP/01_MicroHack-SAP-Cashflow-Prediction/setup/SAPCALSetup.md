# MicroHack Setup

## SAP System
The MicroHack relies on Sales Data, so you'll need an SAP System containing Sales Orders. From technical point of view, we extract Sales Data via a CDS View and via a oData service.

We recommend to use a ´SAP S/4HANA Fully-Activated Appliance´ image from [SAP CAL](http://cal.sap.com).

The code for the CDS View to extract the Sales Order Headers can be found at [ZBD_ISALESDOC_E CDS View](../scripts/zbd_i_salesdocument_e.asddls). The code for this view needs to be imported into your SAP system.
The oData Service used to extract the Sales Order Items is ´/sap/opu/odata/sap/sd_f1814_so_fs_srv/´, which is available in the "SAP S/4HANA Fully-Activated Appliance" image.

### Deployment of the ZBD_ISALESDOC_E view
* logon to the Windows Virtual Machine using Remote Desktop and use the `Administrator` user with the master password entered during SAP CAL deployment.
<img src="../images/SAPCALsetup/01_setup_HanaStudioIcon.jpg" height=80>

* The default workspace is fine, press `Launch`
<img src="../images/SAPCALsetup/02_setup_DefaultWorkspace.jpg" height = 300>

* Switch to the HANA Development perspective : `Window > Perspective > Open Perspective > SAP HANA Development`
<img src="../images/SAPCALsetup/03_setup_HANADevPerspective.jpg" height = 350>

* In the `Project Explorer`tab, Select the `S4H100_S4H_EXT_EN` folder and logon with the proposed user `S4H_EXT`  
<img src="../images/SAPCALsetup/04_setup_projectexplorer.jpg" height = 200>

>Note : The password for the `S4H_EXT` user can be found on the chrome 'Welcome' page which is displayed when logging on via remote desktop or in the 'Getting started' guide in SAP CAL. 

* Create an new `Data Definition`
    *  Select `File > New > Other`
    
    * In the wizard, search for `ABAP` > `Core Data Services` > `Data Definition`.
    <img src="../images/SAPCALsetup/05_setup_CreateDataDefinition.jpg" height = 350>
    
    * Enter the name of CDS View, eg. `ZBD_ISalesDocument_E`
    <img src="../images/SAPCALsetup/06_setup_DataDefinitionName.jpg" height = 500>
    
    * Enter the following code, see [ZBD_ISalesDocument_E](../scripts/zbd_i_salesdocument_e.asddls)
    <img src="../images/SAPCALsetup/07_setup_ViewDefinition.jpg" height = 800>
    
    * Activate the view
    <img src="../images/SAPCALsetup/08_setup_Activate.jpg" height = 50>

* You can test the view by rightClikcing on the view and selecting `Open with > Data Preview`
<img src="../images/SAPCALsetup/09_setup_openwith.jpg" height= 60>

<img src="../images/SAPCALsetup/10_setup_DataPreview.jpg">

* You can also test the view using the SAP Data Dictionary
    * Logon via SAP Logon (SAP Gui is installed in the remote desktop environment)
    <img src="../images/SAPCALsetup/11_setup_saplogon1.jpg" height = 75>
    
    * The S4Hana system is already predefined in the SAP Logon Pad : select and double click to logon
    <img src="../images/SAPCALsetup/12_setup_saplogon2.jpg" height = 300>
    
    * In the logon screen, enter the SAP Credentials: Client: 100, UserId: S4H_Ext
    <img src="../images/SAPCALsetup/13_setup_saplogon3.jpg" height = 500>
    
    * Go to transaction `SE11 - SAP Datadictionary`
        * using Menu : 
        
            * swith to the SAP Standard Menu
            <img src="../images/SAPCALsetup/14_setup_standardMenu.jpg" height=50>
        
            * Double Click `Data Dictionary` in the Menu tree
            <img src="../images/SAPCALsetup/15_setup_ddicMenu.jpg" height = 300>
        
        * or directly enter the transaction shortcut `se11` and press `Enter`
        <img src="../images/SAPCALsetup/16_setup_se11.jpg" height = 40>
    
    * In the SAP Data Dictionary : Enter the view Name `ZBD_ISALESDOC_E`
    <img src="../images/SAPCALsetup/17_setup_ddic1.jpg" height = 300>
    <img src="../images/SAPCALsetup/18_setup_ddic3.jpg" height = 600>
    
    >Note : the SAP DDIC view name is defined by the `@AbapCatalog.sqlViewName` in the Core Data Service Defintion
    
    * Select `Contents` to swith to the `Data Browser`
    <img src="../images/SAPCALsetup/19_setup_ddicContents.jpg" height = 40>
    
    * Press `Execute`of `F8` to see the contents
    <img src="../images/SAPCALsetup/20_setup_databrowserExecute.jpg">
    <img src="../images/SAPCALsetup/21_setup_ddicContents2.jpg" height = 300>

The Setup in the SAP System is now finished.
You can now continue with the setup needed for the Payments : [Payment Setup](../setup/paymentsSetup.md)