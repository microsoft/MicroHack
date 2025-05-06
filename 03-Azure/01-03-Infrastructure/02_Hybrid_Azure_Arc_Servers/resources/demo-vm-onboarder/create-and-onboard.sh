############################################################################################
#                                                                                          #
#    Make sure to adjust the parameters in both scripts to match your intended values!!!   #
#                                                                                          #
############################################################################################

cd ../demo-vm-creator
# create the VMs
./create-vms-and-rgs.sh

cd ../demo-vm-onboarder
# onboard the VMs
./arc-enable-vms.sh