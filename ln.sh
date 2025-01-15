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

# Function to clean and normalize a key
normalize_key() {
    echo "$1" | tr -d '\n' | sed 's/\s\+/ /g'
}

# Load the SSH public key
PUB_KEY=$(normalize_key "$(cat ~/.ssh/id_rsa.pub)")
echo -e "${CYAN}Normalized Public Key:${NC} $PUB_KEY"

# Debugging: function to show processing logs
debug_log() {
    local message=$1
    echo -e "${CYAN}[DEBUG]: $message${NC}"
}

# Add key to LXC containers
add_key_to_lxc() {
    local id=$1
    local status

    debug_log "Processing LXC container ID: $id"

    status=$($SUDO pct status "$id" | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        echo -e "${YELLOW}Skipping LXC container $id (not running).${NC}"
        return
    fi

    echo -e "${CYAN}Checking existing keys in LXC container $id...${NC}"
    existing_keys=$($SUDO pct exec "$id" -- cat /root/.ssh/authorized_keys 2>/dev/null || echo "")
    echo -e "${CYAN}Existing Keys in $id:${NC}\n$existing_keys"

    if echo "$existing_keys" | grep -Fxq "$(normalize_key "$PUB_KEY")"; then
        echo -e "${YELLOW}Key already exists in LXC container $id. Skipping.${NC}"
        return
    fi

    echo -e "${CYAN}Adding SSH key to LXC container $id...${NC}"
    $SUDO pct exec "$id" -- mkdir -p /root/.ssh
    echo "$PUB_KEY" | $SUDO pct exec "$id" -- bash -c "cat >> /root/.ssh/authorized_keys"
    echo -e "${GREEN}SSH key added to LXC container $id.${NC}"
}

# Add key to VMs
add_key_to_vm() {
    local id=$1
    local disk_path
    local mount_dir="/mnt/vm-$id"
    local status

    debug_log "Processing VM ID: $id"

    status=$($SUDO qm status "$id" | awk '{print $2}')
    if [[ "$status" != "running" ]]; then
        echo -e "${YELLOW}Skipping VM $id (not running).${NC}"
        return
    fi

    # Detect Windows VMs and skip
    if $SUDO qm config "$id" | grep -i "ostype" | grep -iq "win"; then
        echo -e "${YELLOW}Skipping VM $id (Windows detected).${NC}"
        return
    fi

    echo -e "${CYAN}Checking existing keys in VM $id...${NC}"
    disk_path=$($SUDO qm config "$id" | grep -E 'scsi|virtio|ide' | head -n1 | awk -F ':' '{print $2}' | awk '{print $1}')
    echo -e "${CYAN}Disk Path for VM $id:${NC} $disk_path"

    $SUDO mkdir -p "$mount_dir"
    if $SUDO guestmount -a "/var/lib/vz/images/$id/$disk_path" -i --rw "$mount_dir"; then
        existing_keys=$(cat "$mount_dir/root/.ssh/authorized_keys" 2>/dev/null || echo "")
        echo -e "${CYAN}Existing Keys in VM $id:${NC}\n$existing_keys"

        if echo "$existing_keys" | grep -Fxq "$(normalize_key "$PUB_KEY")"; then
            echo -e "${YELLOW}Key already exists in VM $id. Skipping.${NC}"
            $SUDO guestunmount "$mount_dir"
            $SUDO rmdir "$mount_dir"
            return
        fi

        echo -e "${CYAN}Adding SSH key to VM $id...${NC}"
        echo "$PUB_KEY" | $SUDO tee -a "$mount_dir/root/.ssh/authorized_keys"
        $SUDO guestunmount "$mount_dir"
        $SUDO rmdir "$mount_dir"
        echo -e "${GREEN}SSH key added to VM $id.${NC}"
    else
        echo -e "${RED}Failed to mount disk for VM $id. Skipping.${NC}"
        $SUDO rmdir "$mount_dir"
    fi
}

# Process LXC containers
if [[ "$PROCESS_LXC" == true ]]; then
    LXC_IDS=$($SUDO pct list | awk 'NR>1 {print $1}')
    if [[ -z "$LXC_IDS" ]]; then
        echo -e "${YELLOW}No LXC containers found.${NC}"
    else
        echo -e "${CYAN}[DEBUG] Found LXC containers: $LXC_IDS${NC}"
        for id in $LXC_IDS; do
            echo -e "${CYAN}[DEBUG] Processing LXC container ID: $id${NC}"
            add_key_to_lxc "$id"
        done
    fi
fi

# Process VMs
if [[ "$PROCESS_VM" == true ]]; then
    VM_IDS=$($SUDO qm list | awk 'NR>1 {print $1}')
    if [[ -z "$VM_IDS" ]]; then
        echo -e "${YELLOW}No VMs found.${NC}"
    else
        echo -e "${CYAN}[DEBUG] Found VMs: $VM_IDS${NC}"
        for id in $VM_IDS; do
            echo -e "${CYAN}[DEBUG] Processing VM ID: $id${NC}"
            add_key_to_vm "$id"
        done
    fi
fi

