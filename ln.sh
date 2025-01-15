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
else
    SUDO=''
fi

# Parse arguments for SSH public key and processing flags
ENCODED_KEY=""
PROCESS_LXC=false
PROCESS_VM=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --lxc) PROCESS_LXC=true ;;
        --vm) PROCESS_VM=true ;;
        *) ENCODED_KEY="$1" ;;
    esac
    shift
done

# Decode and validate the SSH public key
if [[ -z "$ENCODED_KEY" ]]; then
    echo -e "${RED}Error: No SSH public key provided.${NC}"
    exit 1
fi

PUB_KEY=$(echo "$ENCODED_KEY" | base64 -d 2>/dev/null)
if [[ -z "$PUB_KEY" ]]; then
    echo -e "${RED}Error: Decoded public key is empty or invalid.${NC}"
    exit 1
fi

# Normalize the public key
normalize_key() {
    echo "$1" | tr -d '\n' | sed 's/\s\+/ /g'
}
PUB_KEY=$(normalize_key "$PUB_KEY")

# Display the key being processed
echo -e "${CYAN}SSH Public Key being processed:${NC} $PUB_KEY"

# Function to add the key to an LXC container
add_key_to_lxc() {
    local id=$1
    local status

    status=$($SUDO pct status "$id" | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        return
    fi

    existing_keys=$($SUDO pct exec "$id" -- cat /root/.ssh/authorized_keys 2>/dev/null || echo "")

    if ! echo "$existing_keys" | grep -Fxq "$PUB_KEY"; then
        $SUDO pct exec "$id" -- mkdir -p /root/.ssh
        echo "$PUB_KEY" | $SUDO pct exec "$id" -- bash -c "cat >> /root/.ssh/authorized_keys"
    fi
}

# Function to add the key to a VM
add_key_to_vm() {
    local id=$1
    local disk_path
    local mount_dir="/mnt/vm-$id"
    local status

    status=$($SUDO qm status "$id" | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        return
    fi

    disk_path=$($SUDO qm config "$id" | grep -E 'scsi|virtio|ide' | head -n1 | awk -F ':' '{print $2}' | awk '{print $1}')

    $SUDO mkdir -p "$mount_dir"
    if $SUDO guestmount -a "/var/lib/vz/images/$id/$disk_path" -i --rw "$mount_dir"; then
        existing_keys=$(cat "$mount_dir/root/.ssh/authorized_keys" 2>/dev/null || echo "")

        if ! echo "$existing_keys" | grep -Fxq "$PUB_KEY"; then
            echo "$PUB_KEY" | $SUDO tee -a "$mount_dir/root/.ssh/authorized_keys" >/dev/null
        fi

        $SUDO guestunmount "$mount_dir"
        $SUDO rmdir "$mount_dir"
    else
        $SUDO rmdir "$mount_dir"
    fi
}

# Process LXC containers if requested
if [[ "$PROCESS_LXC" == true ]]; then
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1}')
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        for id in $LXC_IDS; do
            add_key_to_lxc "$id"
        done
    fi
fi

# Process VMs if requested
if [[ "$PROCESS_VM" == true ]]; then
    VM_IDS=$($SUDO qm list | awk 'NR>1 {print $1}')
    if [[ -z "$VM_IDS" ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
    else
        for id in $VM_IDS; do
            add_key_to_vm "$id"
        done
    fi
fi

echo -e "${GREEN}SSH key processed for all specified containers and VMs.${NC}"
