#!/bin/bash -eu
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh


echo ""
echo "** Drivers Installation **"
echo ""


########################################
#######    MACHINE SPECIFIC	########
########################################

FOUND_VBOX=`lspci | grep -i vga | grep -i 'virtualbox\|vbox\|vmware' | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	if [ "$INSTALLHEAD" == "YES" ]; then
		DRVINSTALL="virtualbox-guest-utils xf86-video-vmware"
	else
		DRVINSTALL="virtualbox-guest-utils-nox"
	fi
	install_packs "$DRVINSTALL"
	mkdir -p /etc/modules-load.d/
	mkdir -p /etc/modprode.d/
	systemctl enable vboxservice
	echo "options snd-intel8x0 ac97_clock=48000" >> /etc/modprobe.d/vbox-snd-options
else
	echo "VirtualBox not found"
fi

#nvidia proprietary graphic drivers
FOUND_NVIDIA=`lspci | grep -i vga | grep -i nvidia | wc -l`
if [ "$FOUND_NVIDIA" != "0" ]; then
	echo "Found NVidia graphic device"
	export IGNORE_CC_MISMATCH=1
	#for GTX 770
	install_packs "nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings"
	#for GT 8600M
	#install_packs "nvidia-340xx-dkms nvidia-340xx-libgl lib32-nvidia-340xx-libgl"
	nvidia-xconfig
else
	echo "NVidia not found"
fi

FOUND_RADEON=`lspci | grep -i vga | grep -i ATI | grep -i radeon | wc -l`
if [ "$FOUND_RADEON" != "0" ]; then
	echo "Found AMD/ATI Radeon graphic device"
	echo " >> skip since outdated"
else
	echo "AMD/ATI Radeon not found"
fi


FOUND_INTELGRAPHICS=`lspci | grep -i VGA | grep -i intel | wc -l`
if [ "$FOUND_INTELGRAPHICS" != "0" ]; then
	echo "Found Intel Graphic devices"
	install_packs "xf86-video-intel libva-intel-driver libvdpau-va-gl mesa-vdpau libva-vdpau-driver"
	mkdir -p /etc/X11/xorg.conf.d/
	cat > /etc/X11/xorg.conf.d/20-intel.conf << EOF
Section "Device"
	Identifier	"Intel Graphics"
	Driver		"intel"
	Option		"TearFree"	"true"
EndSection
EOF
else
	echo "Intel Graphic devices not found"
fi

#Realtek network devices drivers
FOUND_RLTK=`lspci | grep -i net | grep -i realtek | wc -l`
if [ "$FOUND_RLTK" != "0" ]; then
	echo "Found Realtek network devices"
	echo " >> skipping install"
	#install_packs firmware-realtek
else
	echo "Realtek network devices not found"
fi

#pause "Drivers done"

exit

