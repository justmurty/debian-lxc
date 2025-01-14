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

# Copy the public key to Proxmox
Write-Color "Copying public key to Proxmox ($ProxmoxUser@$ProxmoxHost)..." "Cyan"
$SSHCommand = "ssh-copy-id -i $PublicKeyPath $ProxmoxUser@$ProxmoxHost"
if (!(Invoke-Expression $SSHCommand)) {
    Write-Color "Error: Failed to copy the public key to Proxmox. Exiting." "Red"
    exit
}
Write-Color "Public key successfully copied to Proxmox." "Green"

# Execute the Bash script from GitHub
$GitHubURL = "https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/win/ln.sh"
$RemoteCommand = "bash -c \"\$(wget -qO- $GitHubURL)\""

Write-Color "Executing the script on Proxmox..." "Yellow"
Invoke-Expression "ssh $ProxmoxUser@$ProxmoxHost '$RemoteCommand'"
