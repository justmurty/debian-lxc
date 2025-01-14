# Proxmox SSH Public Key Adder (Windows Compatible)

This script simplifies the process of copying your SSH public key from a Windows laptop to a Proxmox server and its LXC containers and VMs. It ensures seamless setup for SSH access across all instances.

---

## Features
- **Direct Execution**: Run the script directly from the URL without downloading it manually.
- **Windows Compatible**: Designed for use with PowerShell on Windows systems.
- **Automated Key Deployment**: Copies your SSH public key to:
  - Proxmox Server
  - All LXC containers
  - All VMs
- **Interactive**: Prompts for necessary information like Proxmox hostname and username.

---

## Quick Start

### **Run the Script**
1. **Open PowerShell as Administrator**:
   - Press `Win + X` → Select `Windows PowerShell (Admin)`.

 2.**Start the script:**
```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/win/prox_ssh_key_pub.ps1").Content
```

3. **Set Execution Policy if have problem and back to step 2**:
   Temporarily allow script execution:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
