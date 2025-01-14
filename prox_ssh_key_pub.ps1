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

# Execute the script on Proxmox to add the key to LXC containers and VMs
Write-Color "Now adding your public key to LXC containers and VMs on Proxmox..." "Cyan"

$RemoteScript = @"
# Color definitions for the Proxmox script
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if the user is root
if [[ \$EUID -ne 0 ]]; then
    SUDO='sudo'
    echo -e "\$YELLOW Running as non-root user. Using sudo for privileged commands. \$NC"
else
    SUDO=''
    echo -e "\$GREEN Running as root user. \$NC"
fi

# Check if whiptail is installed, if not, install it automatically
if ! command -v whiptail &> /dev/null; then
    echo -e "\$YELLOW whiptail is not installed. Installing... \$NC"
    {
        echo 20
        \$SUDO apt update -y > /dev/null 2>&1
        echo 50
        \$SUDO apt install -y whiptail > /dev/null 2>&1
        echo 100
    } | whiptail --gauge "Installing whiptail..." 6 50 0
    if [[ \$? -ne 0 ]]; then
        echo -e "\$RED Failed to install whiptail. Exiting. \$NC"
        exit 1
    fi
    echo -e "\$GREEN whiptail installed successfully. \$NC"
fi

# Check if the public key exists on Proxmox
if [[ ! -f ~/.ssh/authorized_keys ]]; then
    echo -e "\$RED Error: No authorized_keys file found on Proxmox. \$NC"
    exit 1
fi

# Load the public key from Proxmox
PUB_KEY=\$(cat ~/.ssh/authorized_keys)

# Prompt the user to select options (LXC, VM, or both) using a graphical menu
CHOICES=\$(whiptail --title "Proxmox SSH Key Adder" --checklist \
"Select the instances to process (use SPACE to select, ENTER to confirm):" 15 50 2 \
"LXC" "Process LXC containers" ON \
"VM" "Process VMs" OFF 3>&1 1>&2 2>&3)

if [[ \$? -ne 0 ]]; then
    echo -e "\$RED No selection made. Exiting. \$NC"
    exit 1
fi

# Function to add the key to an LXC container with progress bar
add_key_to_lxc() {
    local VMID=\$1
    echo -e "\$YELLOW Adding SSH key to LXC container \$VMID... \$NC"
    {
        echo 50
        \$SUDO pct exec \$VMID -- mkdir -p /root/.ssh
        echo 75
        \$SUDO pct exec \$VMID -- bash -c "echo \"\$PUB_KEY\" >> /root/.ssh/authorized_keys"
        echo 100
    } | whiptail --gauge "Processing LXC container \$VMID..." 6 50 0
    echo -e "\$GREEN SSH key successfully added to LXC container \$VMID. \$NC"
}

# Function to add the key to a VM with progress bar
add_key_to_vm() {
    local VMID=\$1
    echo -e "\$YELLOW Adding SSH key to VM \$VMID... \$NC"
    DISK_PATH=\$(\$SUDO qm config \$VMID | grep '^scsi\\|^virtio\\|^ide' | head -1 | awk -F ':' '{print \$2}' | awk '{print \$1}')
    MOUNT_DIR="/mnt/vm-\$VMID"

    if [[ -n "\$DISK_PATH" ]]; then
        mkdir -p \$MOUNT_DIR
        {
            echo 50
            \$SUDO guestmount -a "/var/lib/vz/images/\$VMID/\$DISK_PATH" -i --rw \$MOUNT_DIR > /dev/null 2>&1
            echo 75
            echo "\$PUB_KEY" | \$SUDO tee -a "\$MOUNT_DIR/root/.ssh/authorized_keys" > /dev/null
            \$SUDO guestunmount \$MOUNT_DIR > /dev/null 2>&1
            rmdir \$MOUNT_DIR
            echo 100
        } | whiptail --gauge "Processing VM \$VMID..." 6 50 0
        echo -e "\$GREEN SSH key successfully added to VM \$VMID. \$NC"
    else
        echo -e "\$RED No valid disk found for VM \$VMID. Skipping. \$NC"
    fi
}

# Process LXC containers if selected
if [[ \$CHOICES == *"LXC"* ]]; then
    LXC_IDS=\$(\$SUDO pct list | awk 'NR>1 {print \$1}')
    if [[ -z "\$LXC_IDS" ]]; then
        echo -e "\$YELLOW No LXC containers found. \$NC"
    else
        for ID in \$LXC_IDS; do
            add_key_to_lxc \$ID
        done
    fi
fi

# Process VMs if selected
if [[ \$CHOICES == *"VM"* ]]; then
    VM_IDS=\$(\$SUDO qm list | awk 'NR>1 {print \$1}')
    if [[ -z "\$VM_IDS" ]]; then
        echo -e "\$YELLOW No VMs found. \$NC"
    else
        # Check if libguestfs-tools is installed
        if ! dpkg -l | grep -q libguestfs-tools; then
            echo -e "\$YELLOW 'libguestfs-tools' is required for VM processing. Installing now... \$NC"
            {
                echo 30
                \$SUDO apt update -y > /dev/null 2>&1
                echo 70
                \$SUDO apt install -y libguestfs-tools > /dev/null 2>&1
                echo 100
            } | whiptail --gauge "Installing libguestfs-tools..." 6 50 0
        fi
        for ID in \$VM_IDS; do
            add_key_to_vm \$ID
        done
    fi
fi

echo -e "\$CYAN Processing completed on Proxmox. \$NC"
"@

# Execute the remote script on Proxmox
$SSHCommand = "ssh $ProxmoxUser@$ProxmoxHost '$RemoteScript'"
Invoke-Expression $SSHCommand
