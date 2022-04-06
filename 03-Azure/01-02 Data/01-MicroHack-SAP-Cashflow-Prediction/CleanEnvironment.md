# Remove the Microhack environment with Terraform
Once you are finished with the Microhack environment it is best to remove the environment. You can do this by removing the Resource Group.

## Remove the Resource Group
* Click on the Resource Group and choose the option `Delete resource group`. You will need to type the name of the resource group in a textbox for confirmation, this is by default `microhack-sap-data-rg`.

<img src="images/cleanup/removeRG.png" height=300>

* Make sure you are in your home folder 
```
cd ~
```
* Remove the `microhack-sap-data` folder and the hidden `.terraform.d` folder
```
rm -rf microhack-sap-data
rm -rf .terraform.d
```

<img src="images/cleanup/removeTF.png" height=150>