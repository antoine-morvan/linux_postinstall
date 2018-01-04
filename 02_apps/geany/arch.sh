#!/bin/bash -eu
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

echo "   Geany"

PKGS="geany geany-plugins"
AURPKGS="geany-themes-git"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

mkdir -p /etc/skel/.config/geany/
retry "wget -q -O /etc/skel/.config/geany/geany.conf ${SETUP_SCRIPT_LOCATION}/02_apps/geany/geany.conf"

exit 0

