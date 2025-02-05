#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Check if the user is root, if not use sudo
if [[ $EUID -ne 0 ]]; then
    SUDO='sudo'
    echo -e "${YELLOW}Running as non-root user. Using sudo for privileged commands.${NC}"
else
    SUDO=''
    echo -e "${GREEN}Running as root user.${NC}"
fi

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo -e "${RED}Error: 'whiptail' is not installed. Installing it now...${NC}"
    $SUDO apt update && $SUDO apt install -y whiptail
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

# Ask for the public key
PUB_KEY=$(whiptail --title "SSH Public Key" --inputbox "Please paste your SSH public key:" 10 60 3>&1 1>&2 2>&3)

if [[ -z "$PUB_KEY" ]]; then
    echo -e "${RED}Error: No public key provided. Exiting.${NC}"
    exit 1
fi

# Check for available LXC containers
if [[ "$CHOICES" == *"LXC"* ]]; then
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1}')
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        if whiptail --title "LXC Selection" --yesno "Do you want to add the key to all LXC containers?" 10 60; then
            SELECTED_LXC_IDS=$LXC_IDS
        else
            SELECTED_LXC_IDS=$(whiptail --title "Select LXC Containers" --checklist \
                "Choose the LXC containers to process:" 15 50 5 \
                $(for ID in $LXC_IDS; do echo "$ID" "Container $ID" OFF; done) 3>&1 1>&2 2>&3)
        fi
        
        for ID in $SELECTED_LXC_IDS; do
            echo -e "${YELLOW}Adding key to LXC container $ID...${NC}"
            $SUDO pct exec $ID -- mkdir -p /root/.ssh
            $SUDO pct exec $ID -- bash -c "echo \"$PUB_KEY\" >> /root/.ssh/authorized_keys"
            echo -e "${GREEN}Key added to LXC container $ID.${NC}"
        done
    fi
fi

echo -e "${CYAN}Processing completed.${NC}"
