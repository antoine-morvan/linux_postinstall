#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Quicktile"
echo ""


PACKS="python python-gtk2 python-xlib python-dbus python-wnck"

update
upgrade
install_packs $PACKS

mkdir -p /tmp/setupquicktile
(cd /tmp/setupquicktile && git clone https://github.com/ssokolow/quicktile.git)
cp /tmp/setupquicktile/quicktile/quicktile.py /usr/bin/quicktile

mkdir -p /etc/skel/.config/
cat > /etc/skel/.config/quicktile.cfg << EOF
[general]
cfg_schema = 1
UseWorkarea = True
ModMask = <Mod4>

[keys]
space = move-to-center
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