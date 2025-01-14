#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No color

# Prompt the user to paste their public key
echo -e "${CYAN}Please paste your public SSH key (e.g., from ~/.ssh/id_rsa.pub), followed by [ENTER]:${NC}"
read -r PUB_KEY

# Check if the input is not empty
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
    
    # Mount the VM disk to access its filesystem
    DISK_PATH=$(qm config $VMID | grep '^scsi\|^virtio\|^ide' | head -1 | awk -F ':' '{print $2}' | awk '{print $1}')
    MOUNT_DIR="/mnt/vm-$VMID"

    if [[ -n "$DISK_PATH" ]]; then
        mkdir -p $MOUNT_DIR
        guestmount -a "/var/lib/vz/images/$VMID/$DISK_PATH" -i --ro $MOUNT_DIR

        # Check if the authorized_keys file exists
        if [[ -d "$MOUNT_DIR/root/.ssh" ]]; then
            echo "$PUB_KEY" >> "$MOUNT_DIR/root/.ssh/authorized_keys"
        else
            mkdir -p "$MOUNT_DIR/root/.ssh"
            echo "$PUB_KEY" > "$MOUNT_DIR/root/.ssh/authorized_keys"
        fi

        guestunmount $MOUNT_DIR
        rmdir $MOUNT_DIR
        echo -e "${GREEN}Key added to VM $VMID.${NC}"
    else
        echo -e "${RED}No valid disk found for VM $VMID. Skipping.${NC}"
    fi
}

# Iterate through all LXC containers and VMs
for ID in $(qm list | awk 'NR>1 {print $1}') $(pct list | awk 'NR>1 {print $1}'); do
    if qm status $ID &>/dev/null; then
        add_key_to_vm $ID
    elif pct status $ID &>/dev/null; then
        add_key_to_lxc $ID
    else
        echo -e "${RED}Unknown type for ID $ID. Skipping.${NC}"
    fi
done

echo -e "${CYAN}Public key added to all instances.${NC}"
