# Proxmox SSH Public Key Adder

This script simplifies adding your SSH public key to all LXC containers and virtual machines (VMs) in a Proxmox VE environment. It features an interactive menu that allows you to select which instances (LXC, VM, or both) to process and optionally installs the required tools for VM processing.

---

## Features

- **Interactive Menu**: Select whether to process LXC containers, VMs, or both using a simple text-based interface.
- **Public Key Input**: Enter your SSH public key via an easy-to-use input box.
- **Optional Tool Installation**: Automatically installs `libguestfs-tools` for VM processing if required and approved by the user.
- **Continues Processing**: Even if the tools are not installed, the script continues VM processing with limited functionality.
- **Color-Coded Output**: Clear, color-coded logs for each operation (success, warning, or error).

---

## How It Works

1. **Start the Script**:
   Run the script directly in your Proxmox VE terminal:
   ```bash
   bash -c "$(wget -qO- https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/main/prox_ssh_key_pub.sh)"
