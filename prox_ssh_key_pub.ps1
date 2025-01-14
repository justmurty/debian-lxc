# Function to display colored messages
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

# Check if the SSH public key exists on the Windows machine
$PublicKeyPath = "$HOME\.ssh\id_rsa.pub"
if (!(Test-Path $PublicKeyPath)) {
    Write-Color "Error: No SSH public key found at $PublicKeyPath. Please generate one before running this script." "Red"
    exit
}

# Load the SSH public key
$PublicKey = Get-Content $PublicKeyPath
Write-Color "Public key successfully loaded." "Green"

# Get Proxmox connection details
$ProxmoxHost = Read-Host "Enter the IP or hostname of your Proxmox server"
$ProxmoxUser = Read-Host "Enter your Proxmox username (e.g., root)"

# Manually copy the SSH public key
Write-Color "Copying public key to Proxmox ($ProxmoxUser@$ProxmoxHost)..." "Cyan"
try {
    $PublicKeyContent = Get-Content $PublicKeyPath
    $Command = "echo '$PublicKeyContent' | ssh $ProxmoxUser@$ProxmoxHost 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh'"
    Invoke-Expression $Command
    Write-Color "Public key successfully copied to Proxmox." "Green"
} catch {
    Write-Color "Error: Failed to copy the public key to Proxmox." "Red"
    Write-Color $_.Exception.Message "Red"
    exit
}

# Execute the Bash script from GitHub
$GitHubURL = "https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/win/ln.sh"
$RemoteCommand = "bash -c \$(wget -qO- $GitHubURL)"

Write-Color "Executing the script on Proxmox..." "Yellow"
try {
    Invoke-Expression "ssh $ProxmoxUser@$ProxmoxHost \"$RemoteCommand\""
    Write-Color "Script executed successfully on Proxmox." "Green"
} catch {
    Write-Color "Error: Failed to execute the script on Proxmox." "Red"
    Write-Color $_.Exception.Message "Red"
}

# Pause at the end to prevent PowerShell from closing immediately
Write-Color "Press any key to exit..." "Yellow"
Read-Host
