# Proxmox SSH Public Key Adder

This script simplifies adding your SSH public key to all LXC containers and virtual machines (VMs) in a Proxmox VE environment. It ensures your public key is added to each container or VM automatically.

## Features

- Detects all LXC containers and VMs in your Proxmox VE setup.
- Prompts you to paste your SSH public key.
- Automatically adds the key to the appropriate location in each container or VM.

## Prerequisites

Ensure the following before running the script:
1. You have administrative access to the Proxmox VE server.
2. The `libguestfs-tools` package is installed (required for VMs):
   ```bash
   apt install libguestfs-tools

Start with in proxmox shell:
```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/main/prox_ssh_key_pub.sh)"
