#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="terminator"
AURPKGS=""

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

mkdir -p /etc/skel/.config/terminator/
retry "wget -q -O /etc/skel/.config/terminator/config ${SETUP_SCRIPT_LOCATION}/02_apps/terminator/config"

exit 0
