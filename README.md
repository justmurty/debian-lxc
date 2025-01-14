# Proxmox SSH Public Key Adder

This script simplifies adding your SSH public key to LXC containers and virtual machines (VMs) in a Proxmox VE environment. It features an interactive menu for selecting which instances to process, handles the installation of required tools for VMs, and provides clear feedback if no instances are available.

---

## Features

- **Interactive Selection**: Choose to process LXC containers, VMs, or both using a simple text-based interface.
- **Tool Installation**: Automatically installs `libguestfs-tools` for VM processing, with a progress bar, if required.
- **Instance Detection**: Checks for available LXC containers or VMs before processing and provides appropriate feedback.
- **Public Key Input**: Prompts you to enter your SSH public key in a user-friendly way.
- **Color-Coded Feedback**: Clear logs for each operation (success, warning, or error).

---

## How It Works

1. **Start the Script**:
   Run the script directly in your Proxmox VE terminal:
   ```bash
   bash -c "$(wget -qO- https://raw.githubusercontent.com/justmurty/proxmox-ssh_pub-add/refs/heads/main/prox_ssh_key_pub.sh)"
