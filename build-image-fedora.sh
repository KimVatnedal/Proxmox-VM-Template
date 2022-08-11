#! /bin/sh

# This script will download and modify the desired image to prep for template build.
# Script is inspired by 2 separate authors work.
# Austins Nerdy Things: https://austinsnerdythings.com/2021/08/30/how-to-create-a-proxmox-ubuntu-cloud-init-image/
# What the Server: https://whattheserver.com/proxmox-cloud-init-os-template-creation/
# requires libguestfs-tools to be installed.
# This script is designed to be run inside the ProxMox VE host environment.
# Modify the install_dir variable to reflect where you have placed the script and associated files.

. ./build-vars

# Fedora template vars
STORAGE=${storage_location}
IMAGE_FILE=${image_name}
TEMPLATE_ID=${build_vm_id}
TEMPLATE_NAME=${image_name}
VM_ID=${build_vm_id}
VM_NAME='fedora-server'

# Clean up any previous build
rm ${install_dir}${image_name}
rm ${install_dir}build-info

# Grab latest cloud-init image for your selected image
wget ${cloud_img_url}

# insert commands to populate the currently empty build-info file
touch ${install_dir}build-info
echo "Base Image: "${image_name} > ${install_dir}build-info
echo "Packages added at build time: "${package_list} >> ${install_dir}build-info
echo "Build date: "$(date) >> ${install_dir}build-info
echo "Build creator: "${creator} >> ${install_dir}build-info

virt-customize --update -a ${image_name}
virt-customize --install ${package_list} -a ${image_name}
virt-customize --mkdir ${build_info_file_location} --copy-in ${install_dir}build-info:${build_info_file_location} -a ${image_name}
# Clean up dangling machine-id that could be in either /etc/machine-id or /etc/machine-info
virt-customize --touch /etc/machine-id --touch /etc/machine-info --truncate /etc/machine-id --truncate /etc/machine-info -a ${image_name}
qm destroy ${build_vm_id}

# From Hogwarts tutorial (tested working)
qm create $TEMPLATE_ID --name $TEMPLATE_NAME --machine q35 --cpu cputype=host --core 2 --memory 2048 --net0 virtio,bridge=vmbr0 --bios ovmf --ostype l26
qm set $TEMPLATE_ID -efidisk0 $STORAGE:0,format=raw,efitype=4m,pre-enrolled-keys=1
qm importdisk $TEMPLATE_ID $IMAGE_FILE $STORAGE
qm set $TEMPLATE_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$TEMPLATE_ID-disk-1
qm set $TEMPLATE_ID --ide2 $STORAGE:cloudinit
qm set $TEMPLATE_ID --boot c --bootdisk scsi0
qm set $TEMPLATE_ID --serial0 socket --vga serial0
# Added
qm set ${build_vm_id} --agent enabled=1
#
qm template $TEMPLATE_ID
