#!/usr/bin/env bash
set -eu -o pipefail

# Taken from https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm

###########################################################################################
## Fix hosts file
###########################################################################################

HOSTNAME=$(hostname)
# Pick one of the available IP addresses assigned to the machine
ACCESSIBLE_IP=$(ip -4 addr show scope global up | awk '/inet / {print $2}' | cut -d'/' -f1 | head -n 1)
(grep '# proxmox necessity$' /etc/hosts &> /dev/null) || (echo "$ACCESSIBLE_IP $HOSTNAME # proxmox necessity" >> /etc/hosts)


###########################################################################################
## Install Proxmox Kernel
###########################################################################################

SHA512="7da6fe34168adc6e479327ba517796d4702fa2f8b4f0a9833f5ea6e6b48f6507a6da403a274fe201595edc86a84463d50383d07f64bdde2e3658108db7d6dc87"

if [ -f /root/.proxmox.stage.1 ] && [ "$(cat /root/.proxmox.stage.1)" == "${SHA512}.1" ]; then
    echo "Skip Proxmox kernel setup"
else
    echo "Install Proxmox kernel"
    echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
    wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
    echo "${SHA512} /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg" | sha512sum --check --status
    [ $? != 0 ] && echo "ERROR :: Proxmox repository key does not validate the SHA512 checksum" && exit 1
    (
        export DEBIAN_FRONTEND=noninteractive
        apt update && apt full-upgrade -y
        apt install -y proxmox-default-kernel
    )
    echo "${SHA512}.1" > /root/.proxmox.stage.1
    reboot
    exit 0
fi

###########################################################################################
## Install Proxmox VE
###########################################################################################

if [ -f /root/.proxmox.stage.2 ] && [ "$(cat /root/.proxmox.stage.2)" == "${SHA512}.2" ]; then
    echo "Skip Proxmox VE setup"
else
    echo "Install Proxmox VE"
    (
        export DEBIAN_FRONTEND=noninteractive
        apt install -y proxmox-ve postfix open-iscsi chrony
        apt remove -y linux-image-amd64 'linux-image-6.1*'
    )
    update-grub
    echo "${SHA512}.2" > /root/.proxmox.stage.2
fi

