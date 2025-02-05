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
CHOICES=$(whiptail --title "Proxmox SSH Key Manager" --checklist \
"Select the instance types to process:" 15 50 2 \
"LXC" "Process LXC containers" ON \
"VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

if [[ $? -ne 0 ]]; then
    echo -e "${RED}No selection made. Exiting.${NC}"
    exit 1
fi

# Function to install libguestfs-tools with progress bar
install_libguestfs_tools() {
    {
    echo 10
    $SUDO apt update -y > /dev/null 2>&1
    echo 50
    $SUDO apt install -y libguestfs-tools > /dev/null 2>&1
    echo 100
    } | whiptail --gauge "Installing 'libguestfs-tools'..." 6 50 0
}

# Check if VM is selected, and prompt to install libguestfs-tools
if [[ "$CHOICES" == *"VM"* ]]; then
    if whiptail --title "Install libguestfs-tools" --yesno \
    "Do you want to install 'libguestfs-tools'? It is required for proper VM processing." 10 60; then
        install_libguestfs_tools
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

# Process LXC Containers
if [[ "$CHOICES" == *"LXC"* ]]; then
    # Get list of LXC containers
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1 " " $2 " OFF"}')
    
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        # Ask if user wants to select all or specific containers
        if whiptail --title "LXC Containers" --yesno "Do you want to add SSH key to ALL LXC containers?" 10 60; then
            SELECTED_LXC=$($SUDO pct list | awk 'NR>1 {print $1}')
        else
            # Let user select specific LXC containers
            SELECTED_LXC=$(whiptail --title "Select LXC Containers" --checklist \
            "Choose LXC containers to add SSH key:" 20 60 10 \
            $LXC_IDS 3>&1 1>&2 2>&3)
        fi
        
        if [[ $? -eq 0 ]]; then
            for ID in $SELECTED_LXC; do
                # Remove quotes from ID
                ID=$(echo "$ID" | tr -d '"')
                echo -e "${YELLOW}Processing LXC container $ID...${NC}"
                
                # Check if key already exists
                KEY_EXISTS=$($SUDO pct exec $ID -- bash -c "grep -qF \"$PUB_KEY\" /root/.ssh/authorized_keys && echo 'yes' || echo 'no'")
                
                if [[ "$KEY_EXISTS" == "yes" ]]; then
                    echo -e "${GREEN}SSH key already exists in LXC container $ID. Skipping.${NC}"
                else
                    $SUDO pct exec $ID -- mkdir -p /root/.ssh
                    $SUDO pct exec $ID -- bash -c "echo \"$PUB_KEY\" >> /root/.ssh/authorized_keys"
                    echo -e "${GREEN}Key added to LXC container $ID.${NC}"
                fi
            done
        else
            echo -e "${YELLOW}No LXC containers selected.${NC}"
        fi
    fi
fi

# Process VMs
if [[ "$CHOICES" == *"VM"* ]]; then
    # Get list of VMs
    VM_IDS=$($SUDO qm list | awk 'NR>1 {print $1 " " $2 " OFF"}')
    
    if [[ -z "$VM_IDS" ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
    else
        # Ask if user wants to select all or specific VMs
        if whiptail --title "VMs" --yesno "Do you want to add SSH key to ALL VMs?" 10 60; then
            SELECTED_VMS=$($SUDO qm list | awk 'NR>1 {print $1}')
        else
            # Let user select specific VMs
            SELECTED_VMS=$(whiptail --title "Select VMs" --checklist \
            "Choose VMs to add SSH key:" 20 60 10 \
            $VM_IDS 3>&1 1>&2 2>&3)
        fi
        
        if [[ $? -eq 0 ]]; then
            for ID in $SELECTED_VMS; do
                # Remove quotes from ID
                ID=$(echo "$ID" | tr -d '"')
                echo -e "${YELLOW}Processing VM $ID...${NC}"
                
                DISK_PATH=$($SUDO qm config $ID | grep '^scsi\|^virtio\|^ide' | head -1 | awk -F ':' '{print $2}' | awk '{print $1}')
                MOUNT_DIR="/mnt/vm-$ID"
                
                if [[ -n "$DISK_PATH" ]]; then
                    mkdir -p $MOUNT_DIR
                    $SUDO guestmount -a "/var/lib/vz/images/$ID/$DISK_PATH" -i --ro $MOUNT_DIR 2>/dev/null
                    
                    if [[ $? -ne 0 ]]; then
                        echo -e "${RED}Failed to mount VM $ID. Skipping.${NC}"
                    else
                        # Check if key already exists
                        KEY_EXISTS=$(grep -qF "$PUB_KEY" "$MOUNT_DIR/root/.ssh/authorized_keys" 2>/dev/null && echo 'yes' || echo 'no')
                        
                        if [[ "$KEY_EXISTS" == "yes" ]]; then
                            echo -e "${GREEN}SSH key already exists in VM $ID. Skipping.${NC}"
                        else
                            if [[ -d "$MOUNT_DIR/root/.ssh" ]]; then
                                echo "$PUB_KEY" | $SUDO tee -a "$MOUNT_DIR/root/.ssh/authorized_keys" > /dev/null
                            else
                                $SUDO mkdir -p "$MOUNT_DIR/root/.ssh"
                                echo "$PUB_KEY" | $SUDO tee "$MOUNT_DIR/root/.ssh/authorized_keys" > /dev/null
                            fi
                            echo -e "${GREEN}Key added to VM $ID.${NC}"
                        fi
                        
                        $SUDO guestunmount $MOUNT_DIR
                        rmdir $MOUNT_DIR
                    fi
                else
                    echo -e "${RED}No valid disk found for VM $ID. Skipping.${NC}"
                fi
            done
        else
            echo -e "${YELLOW}No VMs selected.${NC}"
        fi
    fi
fi

echo -e "${CYAN}Processing completed.${NC}"
