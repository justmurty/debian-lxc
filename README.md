# Proxmox SSH Public Key Adder

This script simplifies adding your SSH public key to all LXC containers and virtual machines (VMs) in a Proxmox VE environment. It ensures your public key is added to each container or VM automatically.

## Features

- Automatically detects all LXC containers and VMs in your Proxmox VE setup.
- Prompts you to paste your SSH public key.
- Installs `libguestfs-tools` if required for VM processing (optional).
- Processes VMs even if `libguestfs-tools` is not installed, with fallback handling.

## Prerequisites

Before running the script, ensure you:
1. Have administrative access to the Proxmox VE server.
2. Optionally install `libguestfs-tools` manually if you'd like to process VMs more reliably:
   ```bash
   apt install libguestfs-tools

Start with in proxmox shell:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/main/prox_ssh_key_pub.sh)"
