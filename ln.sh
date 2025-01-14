#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Ensure root privileges
if [[ $EUID -ne 0 ]]; then
    SUDO='sudo'
    echo -e "${YELLOW}Running as non-root user. Using sudo.${NC}"
else
    SUDO=''
fi

# Install whiptail if missing
if ! command -v whiptail &> /dev/null; then
    echo -e "${YELLOW}Installing whiptail...${NC}"
    $SUDO apt update -y && $SUDO apt install -y whiptail
fi

# Whiptail menu for instance selection
CHOICES=$(whiptail --title "Proxmox SSH Key Adder" --checklist \
"Select instances to process (use SPACE to select, ENTER to confirm):" 15 50 2 \
"LXC" "Process LXC containers" ON \
"VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}No selection made. Exiting.${NC}"
    exit 1
fi

# Load the SSH public key
PUB_KEY=$(cat ~/.ssh/authorized_keys)

# Add key to LXC containers
if [[ $CHOICES == *"LXC"* ]]; then
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1}')
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        for ID in $LXC_IDS; do
            echo -e "${CYAN}Adding SSH key to LXC container $ID...${NC}"
            $SUDO pct exec $ID -- mkdir -p /root/.ssh
            echo "$PUB_KEY" | $SUDO pct exec $ID -- bash -c "cat >> /root/.ssh/authorized_keys"
            echo -e "${GREEN}SSH key added to LXC container $ID.${NC}"
        done
    fi
fi

# Add key to VMs
if [[ $CHOICES == *"VM"* ]]; then
    VM_IDS=$($SUDO qm list | awk 'NR>1 {print $1}')
    if [[ -z "$VM_IDS" ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
    else
        for ID in $VM_IDS; do
            echo -e "${CYAN}Adding SSH key to VM $ID...${NC}"
            DISK_PATH=$($SUDO qm config $ID | grep -E 'scsi|virtio|ide' | head -n1 | awk -F ':' '{print $2}' | awk '{print $1}')
            MOUNT_DIR="/mnt/vm-$ID"
            $SUDO mkdir -p $MOUNT_DIR
            $SUDO guestmount -a "/var/lib/vz/images/$ID/$DISK_PATH" -i --rw $MOUNT_DIR
            echo "$PUB_KEY" | $SUDO tee -a "$MOUNT_DIR/root/.ssh/authorized_keys"
            $SUDO guestunmount $MOUNT_DIR
            $SUDO rmdir $MOUNT_DIR
            echo -e "${GREEN}SSH key added to VM $ID.${NC}"
        done
    fi
fi
