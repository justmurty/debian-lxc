#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo -e "${RED}Error: 'whiptail' is not installed. Installing it now...${NC}"
    apt update && apt install -y whiptail
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Failed to install 'whiptail'. Exiting.${NC}"
        exit 1
    fi
fi

# Multi-select for LXC and VM
CHOICES=$(whiptail --title "Proxmox SSH Key Adder" --checklist \
"Select the instances to process (use SPACE to select, ENTER to confirm):" 15 50 2 \
"LXC" "Process LXC containers" ON \
"VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}No selection made. Exiting.${NC}"
    exit 1
fi

# Check if VM is selected, and prompt to install libguestfs-tools
if [[ "$CHOICES" == *"VM"* ]]; then
    if whiptail --title "Install libguestfs-tools" --yesno \
"Do you want to install 'libguestfs-tools'? It is required for proper VM processing." 10 60; then
        echo -e "${CYAN}Installing 'libguestfs-tools'...${NC}"
        apt update && apt install -y libguestfs-tools
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Failed to install 'libguestfs-tools'. VM processing may encounter issues.${NC}"
        else
            echo -e "${GREEN}'libguestfs-tools' installed successfully.${NC}"
        fi
    else
        echo -e "${YELLOW}Skipping installation of 'libguestfs-tools'.${NC}"
        echo -e "${RED}VM processing will continue, but full functionality may not be available.${NC}"
    fi
fi

# Ask for the public key
PUB_KEY=$(whiptail --title "SSH Public Key" --inputbox "Please paste your SSH public key:" 10 60 3>&1 1>&2 2>&3)

if [[ -z "$PUB_KEY" ]]; then
    echo -e "${RED}Error: No public key provided. Exiting.${NC}"
    exit 1
fi

# Function to add SSH key to LXC container
add_key_to_lxc() {
    local VMID=$1
    echo -e "${YELLOW}Adding key to LXC container $VMID...${NC}"
    pct exec $VMID -- mkdir -p /root/.ssh
    pct exec $VMID -- bash -c "echo \"$PUB_KEY\" >> /root/.ssh/authorized_keys"
    echo -e "${GREEN}Key added to LXC container $VMID.${NC}"
}

# Function to add SSH key to VM
add_key_to_vm() {
    local VMID=$1
    echo -e "${YELLOW}Adding key to VM $VMID...${NC}"
    
    DISK_PATH=$(qm config $VMID | grep '^scsi\|^virtio\|^ide' | head -1 | awk -F ':' '{print $2}' | awk '{print $1}')
    MOUNT_DIR="/mnt/vm-$VMID"

    if [[ -n "$DISK_PATH" ]]; then
        mkdir -p $MOUNT_DIR
        guestmount -a "/var/lib/vz/images/$VMID/$DISK_PATH" -i --ro $MOUNT_DIR 2>/dev/null

        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Failed to mount VM $VMID. Skipping.${NC}"
        else
            if [[ -d "$MOUNT_DIR/root/.ssh" ]]; then
                echo "$PUB_KEY" >> "$MOUNT_DIR/root/.ssh/authorized_keys"
            else
                mkdir -p "$MOUNT_DIR/root/.ssh"
                echo "$PUB_KEY" > "$MOUNT_DIR/root/.ssh/authorized_keys"
            fi
            guestunmount $MOUNT_DIR
            rmdir $MOUNT_DIR
            echo -e "${GREEN}Key added to VM $VMID.${NC}"
        fi
    else
        echo -e "${RED}No valid disk found for VM $VMID. Skipping.${NC}"
    fi
}

# Process LXC if selected
if [[ "$CHOICES" == *"LXC"* ]]; then
    for ID in $(pct list | awk 'NR>1 {print $1}'); do
        add_key_to_lxc $ID
    done
fi

# Process VM if selected
if [[ "$CHOICES" == *"VM"* ]]; then
    for ID in $(qm list | awk 'NR>1 {print $1}'); do
        add_key_to_vm $ID
    done
fi

echo -e "${CYAN}Public key added to selected instances.${NC}"
