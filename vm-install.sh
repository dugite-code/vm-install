#!/bin/bash

vmname="vserv1"
cdrom="/var/lib/libvirt/images/debian-mini.iso"
ndisk="100"
ncpu="2"
nram="7000"
vncport="5900"

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exec sudo /bin/bash "$0" "$@"
fi

while [[ -z "$install" ]]
do
clear
echo "==== VM-Installer ===="
menu_options=( "Install:" "Name: $vmname" "Cdrom: $cdrom" "Disk: $ndisk ( Gig )" "CPU: $ncpu" "RAM: $nram ( MB )" "VNC: $vncport")
select menu in "${menu_options[@]}" "Quit" ; do
    if (( REPLY == 1 + ${#menu_options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#menu_options[@]} )) ; then
        menu=${menu%%:*}
        break

    else
        echo "Invalid option. Try another one."
    fi
done

case $menu in
        Install)
                install=true
                ;;
        Name)
                unset vmname
                while [[ -z "$vmname" ]]
                do
                        read -p "Enter VM name: " vmname
                        if [[ $vmname == *['!'@#\$%^\&*()_+]* ]]
                        then
                                echo "Error: Invalid characters [!@#$%^&*()_+] found in VM Name"
                                unset vmname
                        fi

                        if [[ $vmname = *[[:space:]]* ]]
                        then
                                echo "Error: Spaces and/or Tabs found in VM Name"
                                unset vmname
                        fi

                        if [[ $vmname =~ [A-Z] ]]
                        then
                                echo "Error: Capitals found in VM Name"
                                unset vmname
                        fi
                done
                ;;
        Cdrom)
                options=( $(find /var/lib/libvirt/images/*.iso -maxdepth 1 -print0 | xargs -0) )

                echo "List of available Operating Systems images"
                select cdrom in "${options[@]}" "Default" ; do
                    if (( REPLY == 1 + ${#options[@]} )) ; then
                        break

                    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
                        echo  "You picked $cdrom"
                        break

                    else
                        echo "Invalid option. Try another one."
                    fi
                done
                ;;
        Disk)
                unset ndisk
                while [[ -z "$ndisk" ]]
                do
                        read -p "Enter VM drive size ( GB ): " ndisk
                        if ! [[ $ndisk =~ ^-?[0-9]+$ ]]
                        then
                                echo "Error: must be a whole number"
                                unset ndisk
                        fi
                done
                ;;
        CPU)
                unset ncpu
                while [[ -z "$ncpu" ]]
                do
                        read -p "Enter cpu number: " ncpu
                        if ! [[ $ncpu =~ ^-?[0-9]+$ ]]
                        then
                                echo "Error: must be a whole number"
                                unset ncpu
                        fi
                done
                ;;
        RAM)
                unset nram
                while [[ -z "$nram" ]]
                do
                        read -p "Enter RAM size: " nram
                        if ! [[ $nram =~ ^-?[0-9]+$ ]]
                        then
                                echo "Error: must be a whole number"
                                unset nram
                        fi
                done
                ;;
        VNC)
                unset vncport
                while [[ -z "$vncport" ]]
                do
                        read -p "Enter VNC port: " vncport
                        if ! [[ $vncport =~ ^-?[0-9]+$ ]]
                        then
                                echo "Error: must be a whole number"
                                unset vncport
                        fi
                done
                ;;

esac
done

# Pre-create VM disk image
qemu-img create -f qcow2 -o preallocation=metadata /var/lib/libvirt/images/$vmname.qcow2 ${ndisk}G

virt-install \
--connect qemu:///system \
--name $vmname \
--ram $nram \
--disk path=/var/lib/libvirt/images/$vmname.qcow2,bus=virtio,cache=none \
--cdrom $cdrom \
--vcpus $ncpu \
--os-type=generic \
--os-variant=generic \
--network bridge=br0 \
--accelerate \
--noapic \
--graphics vnc,listen=127.0.0.1,port=$vncport --noautoconsole

echo "Building helper scripts"
mkdir $vmname

echo 'parent_dir="$(dirname "$(pwd)")"

"$parent_dir"/noVNC/utils/launch.sh --vnc localhost:'"$vncport" | dd of=./$vmname/vnc-$vmname.sh
chmod +x ./$vmname/vnc-$vmname.sh

echo "virsh reboot $vmname" | dd of=./$vmname/rebooot-$vmname.sh
chmod +x ./$vmname/rebooot-$vmname.sh

echo "virsh shutdown $vmname" | dd of=./$vmname/shutdown-$vmname.sh
chmod +x ./$vmname/shutdown-$vmname.sh

echo "virsh snapshot-create-as --domain $vmname --name" '$(date +"%H%M%S_%d-%m-%Y")' "--live"  | dd of=./$vmname/live_snapshot-$vmname.sh
chmod +x ./$vmname/live_snapshot-$vmname.sh

echo $vmname "installed"
