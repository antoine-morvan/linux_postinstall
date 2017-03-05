#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS=""
AURPKGS="skypeforlinux-bin"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"


mkdir -p /etc/skel/.config/skypeforlinux/
cat > /etc/skel/.config/skypeforlinux/settings.json << EOF
{"app.registerSkypeUri":false,"main-window.zoom-level":0,"main-window.isMaximised":false,"main-window.position":{"x":180,"y":22,"width":1024,"height":717},"app.minimizeToTray":true,"app.launchMinimized":true}
EOF


exit

