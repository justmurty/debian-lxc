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

# Check if the SSH public key exists on the laptop
$PublicKeyPath = "$HOME\.ssh\id_rsa.pub"
if (!(Test-Path $PublicKeyPath)) {
    Write-Color "Error: No SSH public key found at $PublicKeyPath. Please generate one before running this script." "Red"
    exit
}

# Load the public key from the laptop
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

# Bash script to execute directly on Proxmox
$BashScript = @"
#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if user is root
if [[ \$EUID -ne 0 ]]; then
    SUDO='sudo'
    echo -e "\$YELLOW Running as non-root user. Using sudo for privileged commands. \$NC"
else
    SUDO=''
    echo -e "\$GREEN Running as root user. \$NC"
fi

# Install whiptail if missing
if ! command -v whiptail &> /dev/null; then
    echo -e "\$YELLOW whiptail is not installed. Installing... \$NC"
    \$SUDO apt update -y && \$SUDO apt install -y whiptail
fi

# Prompt user to select instances
CHOICES=\$(whiptail --title "Proxmox SSH Key Adder" --checklist \
"Select the instances to process (use SPACE to select, ENTER to confirm):" 15 50 2 \
"LXC" "Process LXC containers" ON \
"VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

if [[ \$? -ne 0 ]]; then
    echo -e "\$RED No selection made. Exiting. \$NC"
    exit 1
fi

# Load the public key
PUB_KEY=\$(cat ~/.ssh/authorized_keys)

# Process LXC
if [[ "\$CHOICES" == *"LXC"* ]]; then
    LXC_IDS=\$(\$SUDO pct list | awk 'NR>1 {print \$1}')
    if [[ -z "\$LXC_IDS" ]]; then
        echo -e "\$YELLOW No LXC containers found. \$NC"
    else
        for ID in \$LXC_IDS; do
            echo -e "\$CYAN Adding SSH key to LXC \$ID... \$NC"
            \$SUDO pct exec \$ID -- mkdir -p /root/.ssh
            echo "\$PUB_KEY" | \$SUDO pct exec \$ID -- bash -c "cat >> /root/.ssh/authorized_keys"
            echo -e "\$GREEN SSH key added to LXC \$ID. \$NC"
        done
    fi
fi

# Process VMs
if [[ "\$CHOICES" == *"VM"* ]]; then
    VM_IDS=\$(\$SUDO qm list | awk 'NR>1 {print \$1}')
    if [[ -z "\$VM_IDS" ]]; then
        echo -e "\$YELLOW No VMs found. \$NC"
    else
        for ID in \$VM_IDS; do
            echo -e "\$CYAN Adding SSH key to VM \$ID... \$NC"
            DISK_PATH=\$(\$SUDO qm config \$ID | grep -E 'scsi|virtio|ide' | head -n1 | awk -F ':' '{print \$2}' | awk '{print \$1}')
            MOUNT_DIR="/mnt/vm-\$ID"
            \$SUDO mkdir -p \$MOUNT_DIR
            \$SUDO guestmount -a "/var/lib/vz/images/\$ID/\$DISK_PATH" -i --rw \$MOUNT_DIR
            echo "\$PUB_KEY" | \$SUDO tee -a "\$MOUNT_DIR/root/.ssh/authorized_keys"
            \$SUDO guestunmount \$MOUNT_DIR
            \$SUDO rmdir \$MOUNT_DIR
            echo -e "\$GREEN SSH key added to VM \$ID. \$NC"
        done
    fi
fi
"@

# Execute the Bash script on Proxmox directly via SSH
$BashCommand = "ssh $ProxmoxUser@$ProxmoxHost bash -c '$(echo $BashScript | Out-String | ForEach-Object { $_ -replace "`n", " " })'"
Invoke-Expression $BashCommand
