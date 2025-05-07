############################################################################################
#                                                                                          #
#    Make sure to adjust the parameters in both scripts to match your intended values!!!   #
#                                                                                          #
############################################################################################

echo Creating VMs and resource groups...
./create-vms-and-rgs.sh

echo create users and assign to resource groups...
./assign-users.sh