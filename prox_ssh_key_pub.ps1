# Function to display colored messages in Windows Terminal
function Write-Color {
    param (
        [string]$Text,
        [string]$Color
    )
    $Colors = @{
        "Red" = "Red";
        "Green" = "Green";
        "Yellow" = "Yellow";
        "Cyan" = "Cyan";
        "Reset" = "White"
    }
    Write-Host $Text -ForegroundColor $Colors[$Color]
}

# Check if the SSH public key exists on the win
$PublicKeyPath = "$HOME\.ssh\id_rsa.pub"
if (!(Test-Path $PublicKeyPath)) {
    Write-Color "Error: No SSH public key found at $PublicKeyPath. Please generate one before running this script." "Red"
    exit
}

# Load the public key form win
$PublicKey = Get-Content $PublicKeyPath
Write-Color "Public key successfully loaded." "Green"

# Prompt for the Proxmox server IP or hostname
$ProxmoxHost = Read-Host "Enter the IP or hostname of your Proxmox server"
$ProxmoxUser = Read-Host "Enter your Proxmox username (e.g., root)"

# Copy the public key to Proxmox
Write-Color "Copying public key to Proxmox ($ProxmoxUser@$ProxmoxHost)..." "Cyan"
$SSHCommand = "ssh-copy-id -i $PublicKeyPath $ProxmoxUser@$ProxmoxHost"
if (!(Invoke-Expression $SSHCommand)) {
    Write-Color "Error: Failed to copy the public key to Proxmox. Exiting." "Red"
    exit
}
Write-Color "Public key successfully copied to Proxmox." "Green"

# Execute the script on Proxmox to add the key to LXC containers and VMs
Write-Color "Now adding your public key to LXC containers and VMs on Proxmox..." "Cyan"

$RemoteScript = @"
# Color definitions for the Proxmox script
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if the public key exists on Proxmox
if [[ ! -f ~/.ssh/authorized_keys ]]; then
    echo -e "\$RED Error: No authorized_keys file found on Proxmox. \$NC"
    exit 1
fi

# Load the public key from Proxmox
PUB_KEY=\$(cat ~/.ssh/authorized_keys)

# Function to add the key to an LXC container
add_key_to_lxc() {
    local VMID=\$1
    echo -e "\$YELLOW Adding SSH key to LXC container \$VMID... \$NC"
    pct exec \$VMID -- mkdir -p /root/.ssh
    pct exec \$VMID -- bash -c "echo \"\$PUB_KEY\" >> /root/.ssh/authorized_keys"
    echo -e "\$GREEN SSH key successfully added to LXC container \$VMID. \$NC"
}

# Function to add the key to a VM
add_key_to_vm() {
    local VMID=\$1
    echo -e "\$YELLOW Adding SSH key to VM \$VMID... \$NC"
    DISK_PATH=\$(qm config \$VMID | grep '^scsi\\|^virtio\\|^ide' | head -1 | awk -F ':' '{print \$2}' | awk '{print \$1}')
    MOUNT_DIR="/mnt/vm-\$VMID"

    if [[ -n "\$DISK_PATH" ]]; then
        mkdir -p \$MOUNT_DIR
        guestmount -a "/var/lib/vz/images/\$VMID/\$DISK_PATH" -i --rw \$MOUNT_DIR 2>/dev/null
        if [[ \$? -ne 0 ]]; then
            echo -e "\$RED Failed to mount VM \$VMID. Skipping. \$NC"
        else
            mkdir -p "\$MOUNT_DIR/root/.ssh"
            echo "\$PUB_KEY" >> "\$MOUNT_DIR/root/.ssh/authorized_keys"
            guestunmount \$MOUNT_DIR
            rmdir \$MOUNT_DIR
            echo -e "\$GREEN SSH key successfully added to VM \$VMID. \$NC"
        fi
    else
        echo -e "\$RED No valid disk found for VM \$VMID. Skipping. \$NC"
    fi
}

# Process LXC containers
LXC_IDS=\$(pct list | awk 'NR>1 {print \$1}')
if [[ -z "\$LXC_IDS" ]]; then
    echo -e "\$YELLOW No LXC containers found. \$NC"
else
    for ID in \$LXC_IDS; do
        add_key_to_lxc \$ID
    done
fi

# Process VMs
VM_IDS=\$(qm list | awk 'NR>1 {print \$1}')
if [[ -z "\$VM_IDS" ]]; then
    echo -e "\$YELLOW No VMs found. \$NC"
else
    # Check if libguestfs-tools is installed
    if ! dpkg -l | grep -q libguestfs-tools; then
        echo -e "\$YELLOW 'libguestfs-tools' is required for VM processing. Installing now... \$NC"
        apt update && apt install -y libguestfs-tools
    fi
    for ID in \$VM_IDS; do
        add_key_to_vm \$ID
    done
fi

echo -e "\$CYAN Processing completed on Proxmox. \$NC"
"@

# Execute the remote script on Proxmox
$SSHCommand = "ssh $ProxmoxUser@$ProxmoxHost '$RemoteScript'"
Invoke-Expression $SSHCommand
