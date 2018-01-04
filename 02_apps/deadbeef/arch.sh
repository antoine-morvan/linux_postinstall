#!/bin/bash -eu

BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="deadbeef"
AURPKGS="deadbeef-plugin-fb deadbeef-plugin-gvfs deadbeef-quick-search-gtk2-git"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

mkdir -p /etc/skel/.config/deadbeef/
retry "wget -q -O /etc/skel/.config/deadbeef/config ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/config"


exit

