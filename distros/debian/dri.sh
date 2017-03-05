#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Drivers Installation **"
echo ""

########################################
#######    MACHINE SPECIFIC	########
########################################

FOUND_VBOX=`lspci | grep -i vga | grep -i virtualbox | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	install_packs virtualbox-guest-dkms
else
	echo "VirtualBox not found"
fi

#nvidia proprietary graphic drivers
FOUND_NVIDIA=`lspci | grep -i vga | grep -i nvidia | wc -l`
if [ "$FOUND_NVIDIA" != "0" ]; then
	echo "Found NVidia graphic device"
	install_packs nvidia-glx nvidia-settings nvidia-xconfig $EXTRA
	nvidia-xconfig
	ln -s /etc/X11/XF86Config /usr/share/X11/xorg.conf.d/05-nvidia_graphic.conf
	#/etc/X11/xorg.conf.d/00-graphic.conf
	#nvidia-xconfig -o /usr/share/X11/xorg.conf.d/00-graphic.conf
else
	echo "NVidia not found"
fi

FOUND_RADEON=`lspci | grep -i vga | grep -i ATI | grep -i radeon | wc -l`
if [ "$FOUND_RADEON" != "0" ]; then
	echo "Found AMD/ATI Radeon graphic device"
	install_packs fglrx-driver fglrx-control
	aticonfig --initial --force
else
	echo "AMD/ATI Radeon not found"
fi

#intel wifi drivers
FOUND_INTEL_WIFI=`lspci | grep -i net | grep -i intel | grep -i wi | wc -l`
if [ "$FOUND_INTEL_WIFI" != "0" ]; then
	echo "Found intel wifi device"
	install_packs firmware-iwlwifi wireless-tools
else
	echo "intel wifi not found"
fi

#Realtek network devices drivers
FOUND_RLTK=`lspci | grep -i net | grep -i realtek | wc -l`
if [ "$FOUND_RLTK" != "0" ]; then
	echo "Found Realtek network devices"
	install_packs firmware-realtek
else
	echo "Realtek network devices not found"
fi
