#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="virtualbox virtualbox-host-dkms"
AURPKGS="virtualbox-ext-oracle"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

echo -e "vboxdrv\nvboxnetadp\nvboxnetflt" > /etc/modules-load.d/virtualbox.conf

exit
