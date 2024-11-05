#!/usr/bin/env bash
set -eu -o pipefail

[ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && exit 1

. /etc/os-release
case $ID_LIKE in
    *debian*|*ubuntu*)
        apt-get update
        apt-get upgrade -y
        apt-get install -y \
            net-tools bind9 isc-dhcp-server ipcalc iptraf \
            sudo iptables nftables ca-certificates curl tree rsync vim git dnsutils \
            grepcidr bwm-ng htop nethogs byobu openssh-server
        apt-get autoremove -y
        apt-get clean
        ;;
    *fedora*|*rhel*)
        set +e
        # necessary for some RHEL based distros
        yum install -y epel-release &> /dev/null
        set -e
        yum update -y
        yum install -y \
            net-tools bind dhcp-server ipcalc iptraf \
            sudo iptables nftables ca-certificates curl tree rsync vim git dnsutils \
            grepcidr bwm-ng htop nethogs byobu openssh-server
        ;;
    *)
        echo "[NETCONF] ERROR: unsupported distribution family $ID_LIKE"
        exit 1
        ;;
esac

mkdir -p /opt
git clone https://github.com/antoine-morvan/ovhDynDnsUpdate.git /opt/ovhDynDnsUpdate

exit 0
