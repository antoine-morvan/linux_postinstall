#!/bin/ash -eu

# run as sudo

FASTSETUP=YES

###
### Checks
###

[ `whoami` != root ] && echo "should run as root" && exit 1


#configure proxy for installation...
#test if local server is present
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export ENABLE_PAUSE=NO
export LOGCNT=0


#enable all online repos

sed -i 's/^#http//g' /etc/apk/repositories

apk update
apk upgrade
apk add wget curl

#utility functions
[ ! -e alpine_func.sh ] &&  wget --no-cache -q ${SETUP_SCRIPT_LOCATION}/01_func/alpine_func.sh -O alpine_func.sh
source alpine_func.sh


PACKS="htop bwm-ng  m4 libtool automake autoconf intltool wget bash net-tools zsh samba cifs-utils lshw libtool p7zip htop nethogs iotop parted emacs zip unzip curl fakeroot  fuse cmake  python git screen nmap bzip2 sharutils rsync subversion ttf-dejavu tsocks exfat-utils sshfs  dtach tmux ntfs-3g subversion sdparm hdparm lzip tree cups ghostscript dosfstools intltool  cabextract bwm-ng markdown cloc  tig  openvpn dvtm byobu  vim iptables ruby imagemagick iptraf-ng bash-completion  smartmontools pdftk netcat-openbsd pkgconf unrar rarian "

#  autotools-dev
UIPACKS="geany qalculate-gtk filezilla vlc alsa-utils elementary-icon-theme pidgin xterm gksu rxvt-unicode lightdm lightdm-gtk-greeter terminator pulseaudio pavucontrol paprefs mate-themes wicd wicd-gtk xfce4 xfce4-goodies xfce4-artwork xfce4-session xfce4-settings xfwm4 xfwm4-themes xfconf thunar numlockx pinta  graphviz gparted filezilla faac libboost-all-dev dbus icoutils zenity hexchat gitg xdot  filelight gdmap qt5-default youtube-dl mcomix unetbootin paman pavumeter xprintidle firefox  arandr  gnome-keyring seahorse python-setuptools tlp  update-manager system-config-printer-common nscd "

if [ "$FASTSETUP" != "YES" ]; then
  EXTRAPACKS=" mercurial apache2 lynx php libapache2-mod-php ario audacity keepassx thunderbird ghc clang playonlinux xfburn deluge libreoffice gimp inkscape calibre acetoneiso latex2rtf lyx texmaker pstotext texlive-full pandoc texstudio golang maven gradle openjfx openjfx-source jabref wine handbrake owncloud-client"
  PACKS+=$EXTRAPACKS
fi

install_packs ${PACKS}





echo ""
echo "Done."
echo ""
