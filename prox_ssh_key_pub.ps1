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

# Load the SSH public key and normalize it
$PublicKey = Get-Content $PublicKeyPath -Raw
$EscapedPublicKey = $PublicKey -replace "`r`n", "" -replace "`n", "" -replace "'", "\'" -replace "`"", "\""
Write-Color "Public key successfully loaded and normalized." "Green"

# Get Proxmox connection details
$ProxmoxHost = Read-Host "Enter the IP or hostname of your Proxmox server"
$ProxmoxUser = Read-Host "Enter your Proxmox username (e.g., root)"

# Manually copy the SSH public key
Write-Color "Copying public key to Proxmox ($ProxmoxUser@$ProxmoxHost)..." "Cyan"
try {
    $Command = "echo '$EscapedPublicKey' | ssh $ProxmoxUser@$ProxmoxHost 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh'"
    Invoke-Expression $Command
    Write-Color "Public key successfully copied to Proxmox." "Green"
} catch {
    Write-Color "Error: Failed to copy the public key to Proxmox." "Red"
    Write-Color $_.Exception.Message "Red"
    exit
}

# Send the public key to ln.sh and execute it
Write-Color "Executing the script on Proxmox..." "Yellow"
try {
    $RemoteCommand = "wget -qO- https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/win/ln.sh | bash -s -- --lxc --vm '$EscapedPublicKey'"
    $sshCommand = "ssh -t $ProxmoxUser@$ProxmoxHost `"$RemoteCommand`""
    Invoke-Expression $sshCommand
    Write-Color "Script executed successfully on Proxmox." "Green"
} catch {
    Write-Color "Error: Failed to execute the script on Proxmox." "Red"
    Write-Color $_.Exception.Message "Red"
}

# Pause at the end to prevent PowerShell from closing immediately
Write-Color "Press any key to exit..." "Yellow"
Read-Host
