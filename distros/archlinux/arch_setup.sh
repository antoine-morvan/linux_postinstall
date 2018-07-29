#!/bin/bash -eu
##############################################################
# Script for installing French ArchLinux 				     #
##############################################################
# This script takes place just after booting the ArchLinux   #
# install CD (netinst) :                                     #
#   >> wget http://koub.org/arch.sh   					 #
# If the script is downloaded, it means the network is       #
# already configured...                                      #
#   >> dhcpcd eth0                                           #
# Also the script assumes the keyboard layout has already    #
# been selected.                                             #
#   >> loadkeys fr                                           #
##############################################################


##############################################################
#for debug
export ENABLE_PAUSE=YES


# drive on which grub will be installed 
BOOTDRIVE=/dev/sda

#### partitions for system
#leave commented or empty if system is on BIOS
# UEFI partition must be FAT32 with >= 512MB size
#note: doesnt work ...
#UEFIPARTITION=/dev/sda1
BOOTPARTITION=/dev/sda1 # 512MB ext4 is good
MAINPARTITION=/dev/sda2

# { WIDE_16_10 | WIDE_16_9 | 4_3 }
SCREEN=WIDE_16_10

# if set to YES, install only base packages
TESTSYSTEM=YES
INSTALLHEAD=YES
CRYPT=NO

##############################################################

# mountpoint for the new system in the install CD filesystem
# (default should be ok)
MOUNTPOINT=/mnt/hdd

#mapper names
CRYPT_DEVMAPPERNAME=rootcrypt
LVM_GROUPNAME=lvmgroup
SWAP_LOGICAL_VOLUME_NAME=lvswap
ROOT_LOGICAL_VOLUME_NAME=lvroot

#partition paths
CRYPTPARTITION=$MAINPARTITION
if [ "$CRYPT" == "YES" ]; then
	echo "LVMPARTITION uses cryptmapper"
	LVMPARTITION=/dev/mapper/$CRYPT_DEVMAPPERNAME
else
	echo "LVMPARTITION is main partition"
	LVMPARTITION=$MAINPARTITION
fi
SWAPPARTITION=/dev/mapper/$LVM_GROUPNAME-$SWAP_LOGICAL_VOLUME_NAME
ROOTPARTITION=/dev/mapper/$LVM_GROUPNAME-$ROOT_LOGICAL_VOLUME_NAME


#configure proxy for installation...
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
##############################################################

function print_doc {
	clear
	echo ""
	echo " ######################"
	echo " # I. Prepare install #"
	echo " ######################"
	echo ""
	echo "Example for : "
	echo "  /dev/sda1 >> /boot "
	echo "  /dev/sda2 >> swap"
	echo "  /dev/sda3 >> /"
	echo "  /dev/sdb1 >> /home"
	echo ""
	echo "0. loadkeys, configure network has already been done."
	echo "1. edit script to change variables : {vi,nano} $0"
	echo "2. edit partitions of drives using cfdisk"
	echo "    >> cfdisk /dev/sda && cfdisk /dev/sdb"
	echo "3. format partitions using mkfs"
	echo "    >> mkfs.ext3 /dev/sda1 && mkswap /dev/sda2 && mkfs.ext4 /dev/sda3 "
	echo "       && mkfs.ext4 /dev/sdb1"
	echo "4. Create mount point, mount drives, and activate swap"
	echo "    >> mkdir -p $MOUNTPOINT && mount /dev/sda3 $MOUNTPOINT"
	echo "    >> mkdir -p $MOUNTPOINT/boot && mount /dev/sda1 $MOUNTPOINT/boot"
	echo "    >> mkdir -p $MOUNTPOINT/home && mount /dev/sdb1 $MOUNTPOINT/home"
	echo "    >> swapon /dev/sda2"
	echo "5. Call again the script with argument install : \"$0 workstation\""
  echo "          or \"$0 server\""
	echo ""
}

[ "$#" == "0" ] && print_doc && exit 1
case $1 in
  server|workstation)
    echo "Mode is $1"
    SETUP_MODE=$1
    ;;
  *)
    print_doc
    exit 1
    ;;
esac

#prompts at begining
if [ "$CRYPT" == "YES" ]; then
  #crypt
  [ -e /dev/mapper/$CRYPT_DEVMAPPERNAME ] && cryptsetup luksClose $CRYPT_DEVMAPPERNAME
  echo " #######################"
  echo " # Cryptsetup password #"
  echo " #######################"
  echo ""
  set +e
  read -s -p "Volume password : " LUKSPASSWD
  echo ""
  read -s -p "Volume password (confirm) : " LUKSPASSWD2
  echo ""
  while [ "$LUKSPASSWD" != "$LUKSPASSWD2" ]; do
    echo "error: passwords do not match"
    echo ""
    read -s -p "Volume password : " LUKSPASSWD
    echo ""
    read -s -p "Volume password (confirm) : " LUKSPASSWD2
    echo ""
  done
  set -e
fi

#utility functions
wget --no-cache -q "${SETUP_SCRIPT_LOCATION}/01_func/arch_func.sh" -O arch_func.sh
source arch_func.sh

TO_REMOVE+=" arch_func.sh"
TO_REMOVE+=" retry_mainlog_*.log"
if [ "$SCREEN" == "WIDE_16_9" ]; then
  BG=/usr/share/wallpapers/wallarch-wide_16_9.png
else
  if [ "$SCREEN" == "WIDE_16_10" ]; then
    BG=/usr/share/wallpapers/wallarch-wide_16_10.png
  else
    BG=/usr/share/wallpapers/wallarch.png
  fi
fi
echo "$BG" > setup.dat
echo "${SETUP_SCRIPT_LOCATION}" >> setup.dat
echo "${TESTSYSTEM}" >> setup.dat
echo "${INSTALLHEAD}" >> setup.dat
echo "${BOOTDRIVE}" >> setup.dat
echo "${BOOTPARTITION}" >> setup.dat
TO_REMOVE+=" setup.dat"

mkdir -p $MOUNTPOINT
ARCH=`uname -m`
pause "installing on $ARCH"
pause "into $MOUNTPOINT"

##########################################
########  SETUP PACKET MANAGER   #########
##########################################
# select archlinux.fr mirror
if [ ! -a /etc/pacman.d/mirrorlist.backup ];
then
  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
  cp /etc/pacman.conf /etc/pacman.conf.backup
fi
echo "Server = http://mir.archlinux.fr/\$repo/os/\$arch" > /etc/pacman.d/mirrorlist
echo "Server = http://mir1.archlinux.fr/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = http://delta.archlinux.fr/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist
echo "Server = http://mirrors.kernel.org/archlinux/\$repo/os/\$arch" >> /etc/pacman.d/mirrorlist

echo "" > /tmp/pacman.conf
echo "[archlinuxfr]" >> /tmp/pacman.conf
echo "SigLevel = Never" >> /tmp/pacman.conf
echo "Server = http://repo.archlinux.fr/\$arch" >> /tmp/pacman.conf

if [ "$ARCH" == "x86_64" ];
then
  echo "" >> /tmp/pacman.conf
  echo "[multilib]" >> /tmp/pacman.conf
  echo "Include = /etc/pacman.d/mirrorlist" >> /tmp/pacman.conf
fi
[ "`grep archlinuxfr /etc/pacman.conf | wc -l`" == "0" ] && cat /tmp/pacman.conf >> /etc/pacman.conf

pause "pacman configured"
#######################################
########  SETUP FILE SYSTEM   #########
#######################################

function try_umount {
  NBMOUNT=`mount | grep $1 | wc -l`
  if [ "$NBMOUNT" -ge 1 ]; then
    umount $1
  fi
}

#umount all
echo "doing unmount 1"
try_umount  $MOUNTPOINT/boot/efi
echo "doing unmount 2"
try_umount $MOUNTPOINT/boot
echo "doing unmount 3"
try_umount $MOUNTPOINT

echo "disable all swap"
swapoff -a

echo "umount done"

RAMSIZE=`free -h | grep Mem | xargs | cut -d" " -f2 | sed 's/,/./g'`

# delete lvm physical volume if present on used partitions

function try_lvm_delete {
  echo "try delete LVM: $1"
  ISMOUNT=`pvs -o pv_name | grep $1 | wc -l`
  if [ "$ISMOUNT" -ge 1 ]; then
    echo " >> delete lv"
    PARTLVMGROUP=`pvs $1 -o vg_name | tail -n -1 | head -n 1 | xargs`
    lvremove $PARTLVMGROUP -q -y
    echo " >> delete vg"
    vgremove $PARTLVMGROUP
    echo " >> delete pv"
    pvremove $1
    echo " >> done"
  else
    echo " >> abort"
  fi
}

try_lvm_delete $BOOTPARTITION
try_lvm_delete $MAINPARTITION

echo "lvm delete done"

#reformat
if [ -z ${UEFIPARTITION+x} ]; then
  echo "no EFI, skip format"
else
  echo "EFI partition found, format"
  mkfs.vfat -F32 $UEFIPARTITION
fi
echo "mkfs.ext4 $BOOTPARTITION -L boot"
mkfs.ext4 $BOOTPARTITION -L boot -F

mkdir -p $MOUNTPOINT
if [ "$CRYPT" == "YES" ]; then
  echo "cryptsetup -q --use-urandom -c aes-xts-plain64 -h whirlpool -s 512 luksFormat $CRYPTPARTITION"
  echo $LUKSPASSWD | cryptsetup -q -c aes-xts-plain64 -h whirlpool -s 512 luksFormat $CRYPTPARTITION
  echo ""
  echo "cryptsetup luksOpen $CRYPTPARTITION $CRYPT_DEVMAPPERNAME"
  echo $LUKSPASSWD | cryptsetup luksOpen $CRYPTPARTITION $CRYPT_DEVMAPPERNAME
  echo ""
fi

pause "luks configured"

echo "pvcreate -y $LVMPARTITION"
pvcreate -y $LVMPARTITION

pause "pv created"

echo "vgcreate $LVM_GROUPNAME $LVMPARTITION"
vgcreate -y $LVM_GROUPNAME $LVMPARTITION

pause "vg created"

echo "lvcreate -C y -L $RAMSIZE $LVM_GROUPNAME -n $SWAP_LOGICAL_VOLUME_NAME"
lvcreate -y -C y -L $RAMSIZE $LVM_GROUPNAME -n $SWAP_LOGICAL_VOLUME_NAME
echo "mkswap $SWAPPARTITION -L swap"
mkswap $SWAPPARTITION -L swap
swapon $SWAPPARTITION

pause "swap created and on"

echo "lvcreate -l +100%FREE $LVM_GROUPNAME -n $ROOT_LOGICAL_VOLUME_NAME"
lvcreate -y -l +100%FREE $LVM_GROUPNAME -n $ROOT_LOGICAL_VOLUME_NAME
echo "mkfs.ext4 $ROOTPARTITION -L root"
mkfs.ext4 $ROOTPARTITION -L root -F

echo " - mount $ROOTPARTITION $MOUNTPOINT"
mount $ROOTPARTITION $MOUNTPOINT
  
mkdir -p $MOUNTPOINT/boot
echo " - mount $BOOTPARTITION $MOUNTPOINT/boot"
mount $BOOTPARTITION $MOUNTPOINT/boot

#reformat
if [ -z ${UEFIPARTITION+x} ]; then
  echo "no EFI, skip mount"
else
  echo "EFI partition found, mount it"
  mkdir -p $MOUNTPOINT/boot/efi
  mount $UEFIPARTITION $MOUNTPOINT/boot/efi
fi

pause "FS configured"

##################################
########  SETUP  SYSTEM   ########
##################################
# install base systeme
#	update repos information
pacman -Sy
#	update keyring only
pacman --noconfirm -S archlinux-keyring

pause "keyring configured"

#	no system update: can cause kernel panics

PKGS="base wget os-prober bash grub sudo gptfdisk efibootmgr lvm2 device-mapper btrfs-progs net-tools wireless_tools"
if [ "$TESTSYSTEM" != "YES" ]; then
  case $SETUP_MODE in
    server)
      PKGS+=" zsh syslinux linux-lts"
      ;;
    workstation)
      PKGS+=" zsh syslinux linux-zen linux-lts"
      ;;
    esac
fi

pacstrap $MOUNTPOINT $PKGS
#	
pause "system bootstraped"

#preconfig system
cat /tmp/pacman.conf >> $MOUNTPOINT/etc/pacman.conf
cp /etc/resolv.conf $MOUNTPOINT/etc/resolv.conf
genfstab -U -p $MOUNTPOINT >> $MOUNTPOINT/etc/fstab


sed -i "s#GRUB_CMDLINE_LINUX=\"#GRUB_CMDLINE_LINUX=\"resume=$SWAPPARTITION #g" $MOUNTPOINT/etc/default/grub
if [ "$CRYPT" == "YES" ]; then
  #edit the boot options for cryptsetup
  sed -i "s#GRUB_CMDLINE_LINUX=\"#GRUB_CMDLINE_LINUX=\"cryptdevice=$CRYPTPARTITION:$CRYPT_DEVMAPPERNAME root=$ROOTPARTITION #g " $MOUNTPOINT/etc/default/grub
fi

cp setup.dat arch_func.sh $MOUNTPOINT/
TO_REMOVE+=" $MOUNTPOINT/setup.dat $MOUNTPOINT/arch_func.sh $MOUNTPOINT/retry_mainlog_*.log"

export LOGCNT=0
pause "system preconfigured; about to run arch_finish.sh..."	
#execute scrit after chrooting in the new system
# The following script is executed after chrooting in the new system.
retry "wget --no-cache $SETUP_SCRIPT_LOCATION/distros/archlinux/arch_finish.sh -O $MOUNTPOINT/arch_finish.sh"
echo "wget done"
TO_REMOVE+=" $MOUNTPOINT/arch_finish.sh"
chmod +x $MOUNTPOINT/arch_finish.sh

if [ -z ${UEFIPARTITION+x} ]; then
  arch-chroot $MOUNTPOINT ./arch_finish.sh $BOOTDRIVE $SETUP_MODE
else
  arch-chroot $MOUNTPOINT ./arch_finish.sh $BOOTDRIVE $SETUP_MODE $UEFIPARTITION
fi

pause "system setup; removing logs, unmounting devices..."
rm -v $TO_REMOVE
umount -R $MOUNTPOINT
swapoff $SWAPPARTITION

echo ""
echo " ###################"
echo " # Reboot          #"
echo " ###################"
echo ""
echo ""

exit 0
#end

