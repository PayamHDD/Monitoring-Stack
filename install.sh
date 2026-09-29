#!/usr/bin/env bash
show_banner() {
    cat <<EOF
╔══════════════════════════════════════════════════════════════╗
║                  Monitoring Stack Installation               ║
╠══════════════════════════════════════════════════════════════╣
║  Tested on:                                                  ║
║    - Oracle Linux 8 | 9 | 10                                 ║
║    - Rocky Linux  9 | 10                                     ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

check_os() {
    if [[ -f "/etc/redhat-release" ]]; then
        echo "$(cat /etc/redhat-release) Detected!"
    else
        echo "[-] Unsupported OS Detected!"
        exit 1
    fi
}

install_ansible() {
    echo "[*] Enabling EPEL repository..."
    dnf -y install epel-release || return 1

    echo "Installing ansible..."
    dnf -y install ansible || return 1

    ansible --version &> /dev/null
    if [[ "$?" -eq 0 ]]; then
        echo "[+] $(ansible --version | head -n 1) installed successfully."
    else
        echo "[-] ansible installation failed (exit code: $rc)."
        return "$?"
    fi
}

install_docker() {
    echo "[*] Installing dnf-plugins-core..."
    dnf -y install dnf-plugins-core || return 1

    echo "[*] Adding Docker repo..."
    dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo || return 1

    echo "[*] Installing Docker..."
    dnf -y install docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin || return 1

    echo "[*] Enabling and starting Docker service..."
    systemctl enable --now docker || return 1

    echo "[*] Testing installation..."
    docker run --rm hello-world >/dev/null
    if [[ "$?" -eq 0 ]]; then
        echo "[+] Docker installed successfully."
    else
        echo "[-] hello-world test failed (exit code: $rc)."
        return "$?"
    fi
}
# banner
show_banner

# Initial checks
## Root check
if [[ $EUID -ne 0 ]]; then
    echo "[-] This script must be run as root (or with sudo)." >&2
    exit 1
fi
## OS check
check_os
## Config files check
check_config

# Main Program
# Check if Docker is installed (and is not the Podman shim)
if command -v docker &>/dev/null && ! docker --version 2>/dev/null | grep -qi podman; then
    echo "[+] $(docker --version) found. Skipping installation."

    if systemctl is-active --quiet docker; then
        echo "    Service active:  OK"
    else
        echo "    Service active:  NOT OK"
    fi

    if systemctl is-enabled --quiet docker; then
        echo "    Service enabled: OK"
    else
        echo "    Service enabled: NOT OK"
    fi
else
    echo "[!] Docker not found. Trying to install..."
    install_docker || { echo "[-] Installation failed." >&2; exit 1; }
fi

# Check if ansible is installed
if command -v ansible &>/dev/null; then
    echo "[+] $(ansible --version | head -n 1) found. Skipping installation."
else
    echo "[!] Ansible not found. Trying to install..."
    install_ansible || { echo "[-] Installation failed." >&2; exit 1; }
fi

