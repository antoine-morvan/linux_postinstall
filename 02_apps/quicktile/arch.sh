#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="python2-six"
AURPKGS="quicktile-git"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"


mkdir -p /etc/skel/.config/
cat > /etc/skel/.config/quicktile.cfg << EOF
[general]
cfg_schema = 1
UseWorkarea = True
ModMask = <Mod4>

[keys]
space = middle
H = horizontal-maximize
V = vertical-maximize
KP_0 = maximize
KP_1 = bottom-left
KP_2 = bottom
KP_3 = bottom-right
KP_4 = left
KP_5 = middle
KP_6 = right
KP_7 = top-left
KP_8 = top
KP_9 = top-right
Return = monitor-switch
Up = top
Down = bottom
Left = left
Right = right

EOF


mkdir -p /etc/xdg/autostart/
cat > /etc/xdg/autostart/quicktile.desktop << EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Name=QuickTile
GenericName=Window-Tiling Helper
Type=Application
Exec=quicktile --daemonize
Categories=Utility;

EOF
chmod +x /etc/xdg/autostart/quicktile.desktop

exit

