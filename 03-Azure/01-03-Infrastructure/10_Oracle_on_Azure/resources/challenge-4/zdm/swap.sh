#!/bin/sh

# Percent of space on the ephemeral disk to dedicate to swap. Here 30% is being used. Modify as appropriate.
PCT=0.3

# Location of the swap file. Modify as appropriate based on the location of the ephemeral disk.
LOCATION=/mnt

if [ ! -f ${LOCATION}/swapfile ]
then

    # Get size of the ephemeral disk and multiply it by the percent of space to allocate
    size=$(/bin/df -m --output=target,avail | /usr/bin/awk -v percent="$PCT" -v pattern=${LOCATION} '$0 ~ pattern {SIZE=int($2*percent);print SIZE}')
    echo "$size MB of space allocated to swap file"

     # Create an empty file first and set correct permissions
    /bin/dd if=/dev/zero of=${LOCATION}/swapfile bs=1M count=$size
    /bin/chmod 0600 ${LOCATION}/swapfile

    # Make the file available to use as swap
    /sbin/mkswap ${LOCATION}/swapfile
fi

# Enable swap
/sbin/swapon ${LOCATION}/swapfile
/sbin/swapon -a

# Display current swap status
/sbin/swapon -s