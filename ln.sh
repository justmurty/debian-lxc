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

# Parse arguments for non-interactive mode
PROCESS_LXC=false
PROCESS_VM=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --lxc)
            PROCESS_LXC=true
            shift
            ;;
        --vm)
            PROCESS_VM=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Interactive mode fallback if no arguments are provided
if [[ "$PROCESS_LXC" == false && "$PROCESS_VM" == false ]]; then
    if [[ ! -t 1 ]]; then
        echo -e "${YELLOW}Non-interactive mode detected but no options provided. Defaulting to process all.${NC}"
        PROCESS_LXC=true
        PROCESS_VM=true
    else
        CHOICES=$(whiptail --title "Proxmox SSH Key Adder" --checklist \
        "Select instances to process (use SPACE to select, ENTER to confirm):" 15 50 2 \
        "LXC" "Process LXC containers" ON \
        "VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]]; then
            echo -e "${RED}No selection made. Exiting.${NC}"
            exit 1
        fi

        if [[ "$CHOICES" == *"LXC"* ]]; then
            PROCESS_LXC=true
        fi
        if [[ "$CHOICES" == *"VM"* ]]; then
            PROCESS_VM=true
        fi
    fi
fi

# Load the SSH public key
PUB_KEY=$(cat ~/.ssh/authorized_keys)

# Add key to LXC containers
if [[ "$PROCESS_LXC" == true ]]; then
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1}')
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        for ID in $LXC_IDS; do
            STATUS=$($SUDO pct status $ID | awk '{print $2}')
            if [[ "$STATUS" != "running" ]]; then
                echo -e "${YELLOW}Skipping LXC container $ID (not running).${NC}"
                continue
            fi
            echo -e "${CYAN}Adding SSH key to LXC container $ID...${NC}"
            $SUDO pct exec $ID -- mkdir -p /root/.ssh
            echo "$PUB_KEY" | $SUDO pct exec $ID -- bash -c "cat >> /root/.ssh/authorized_keys"
            echo -e "${GREEN}SSH key added to LXC container $ID.${NC}"
        done
    fi
fi

# Add key to VMs
if [[ "$PROCESS_VM" == true ]]; then
    VM_IDS=$($SUDO qm list | awk 'NR>1 {print $1}')
    if [[ -z "$VM_IDS" ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
    else
        for ID in $VM_IDS; do
            STATUS=$($SUDO qm status $ID | awk '{print $2}')
            if [[ "$STATUS" != "running" ]]; then
                echo -e "${YELLOW}Skipping VM $ID (not running).${NC}"
                continue
            fi
            echo -e "${CYAN}Adding SSH key to VM $ID...${NC}"
            DISK_PATH=$($SUDO qm config $ID | grep -E 'scsi|virtio|ide' | head -n1 | awk -F ':' '{print $2}' | awk '{print $1}')
            MOUNT_DIR="/mnt/vm-$ID"
            $SUDO mkdir -p $MOUNT_DIR
            if $SUDO guestmount -a "/var/lib/vz/images/$ID/$DISK_PATH" -i --rw $MOUNT_DIR; then
                echo "$PUB_KEY" | $SUDO tee -a "$MOUNT_DIR/root/.ssh/authorized_keys"
                $SUDO guestunmount $MOUNT_DIR
                $SUDO rmdir $MOUNT_DIR
                echo -e "${GREEN}SSH key added to VM $ID.${NC}"
            else
                echo -e "${RED}Failed to mount disk for VM $ID. Skipping.${NC}"
                $SUDO rmdir $MOUNT_DIR
            fi
        done
    fi
fi
