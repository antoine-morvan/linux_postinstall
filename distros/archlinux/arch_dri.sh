#!/bin/bash
BG=`cat /setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | tail -n 1`
source /arch_func.sh


echo ""
echo "** Drivers Installation **"
echo ""


########################################
#######    MACHINE SPECIFIC	########
########################################

FOUND_VBOX=`lspci | grep -i vga | grep -i virtualbox | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	DRVINSTALL="virtualbox-guest-utils"
	install_packs "$DRVINSTALL"
	mkdir -p /etc/modules-load.d/
	mkdir -p /etc/modprode.d/
	systemctl enable vboxservice
	echo "options snd-intel8x0 ac97_clock=48000" >> /etc/modprode.d/vbox-snd-options
else
	echo "VirtualBox not found"
fi

#nvidia proprietary graphic drivers
FOUND_NVIDIA=`lspci | grep -i vga | grep -i nvidia | wc -l`
if [ "$FOUND_NVIDIA" != "0" ]; then
	echo "Found NVidia graphic device"
	yaourt -Rdd --noconfirm lib32-mesa-libgl
	yaourt -Rdd --noconfirm mesa-libgl
	export IGNORE_CC_MISMATCH=1
	install_packs "nvidia-340xx-dkms nvidia-340xx-libgl lib32-nvidia-340xx-libgl"
	nvidia-xconfig
else
	echo "NVidia not found"
fi

FOUND_RADEON=`lspci | grep -i vga | grep -i ATI | grep -i radeon | wc -l`
if [ "$FOUND_RADEON" != "0" ]; then
	echo "Found AMD/ATI Radeon graphic device"
	pause "ati start"
######  install new repo
	cat >> /etc/pacman.conf << "EOF"

[catalyst]
Server = http://catalyst.wirephire.com/repo/catalyst/$arch
## Mirrors, if the primary server does not work or is too slow:
#Server = http://70.239.162.206/catalyst-mirror/repo/catalyst/$arch
#Server = http://mirror.rts-informatique.fr/archlinux-catalyst/repo/catalyst/$arch
#Server = http://mirror.hactar.bz/Vi0L0/catalyst/$arch
EOF
	CATALYST_PGP_KEY_ID=653C3094
	echo "BYE" | dirmngr
	pacman-key -r $CATALYST_PGP_KEY_ID
	pacman-key --lsign-key $CATALYST_PGP_KEY_ID
######  setup drivers
	pacman -Syu
	yaourt -Rdd --noconfirm lib32-mesa-libgl
	yaourt -Rdd --noconfirm mesa-libgl
	install_packs "catalyst-hook catalyst-utils catalyst-libgl lib32-catalyst-utils lib32-catalyst-libgl"
######  config system
	aticonfig --initial --force
	systemctl enable catalyst-hook
	sed -i 's/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\" nomodeset /g' /etc/default/grub
	#systemctl enable atieventsd
else
	echo "AMD/ATI Radeon not found"
fi


FOUND_INTELGRAPHICS=`lspci | grep -i VGA | grep -i intel | wc -l`
if [ "$FOUND_INTELGRAPHICS" != "0" ]; then
	echo "Found Intel Graphic devices"
	install_packs "libva-intel-driver libvdpau-va-gl mesa-vdpau libva-vdpau-driver"
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

