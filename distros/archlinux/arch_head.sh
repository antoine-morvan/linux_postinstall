#!/bin/bash -eu
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

SETUP_MODE=$1

##########################
#######	 SETUP	 #########
##########################

#xorg-utils xorg-server-utils
PACKS="xorg xorg-server xorg-xinit xorg-util-macros xorg-twm xorg-xclock xdg-user-dirs xterm rxvt-unicode urxvt-url-select lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings terminator pulseaudio pavucontrol paprefs mate-themes wicd wicd-gtk xfce4 xfce4-goodies xfce4-artwork xfce4-session xfce4-settings xfwm4 xfwm4-themes xfconf xscreensaver-arch-logo thunar numlockx pinta gvfs-smb ruby imagemagick librsvg iptraf-ng arandr elementary-icon-theme gtk-engines xarchiver-gtk2 gnome-keyring seahorse gtk-engine-murrine python-setuptools gparted filezilla keepassxc veracrypt lsb-release smartmontools"

case $SETUP_MODE in
  workstation)
    PACKS+=" tlp graphviz system-config-printer vlc pidgin faac boost glu mesa-demos dbus jdk8-openjdk icoutils wxpython zenity"
    ;;
esac

if [ "$TESTSYSTEM" != "YES" ]; then
	EXTRA=" hexchat ario deluge xfburn acetoneiso2"
	EXTRA+=" latex2rtf lyx texmaker texlive-most pandoc texstudio "
	EXTRA+=" maven gradle gitg xdot filelight gdmap qt5 youtube-dl "
	EXTRA+=" mcomix tigervnc wireshark-gtk mkvtoolnix-gui"

  case $SETUP_MODE in
    workstation)
      EXTRA+=" avidemux-cli audacity handbrake libreoffice libreoffice-fresh-fr gimp inkscape thunderbird thunderbird-i18n-fr calibre jdk7-openjdk jdk9-openjdk openjdk7-src openjdk8-src openjdk9-src go java-openjfx java-openjfx-doc java-openjfx-src cordova"
      ;;
  esac

  PACKS+=$EXTRA
fi
#nextcloud
AURPACKS="gksu pasystray-gtk2-standalone paman pavumeter qalculate-gtk-nognome xprintidle archlinux-artwork xfce4-multiload-ng-plugin-gtk2 gnome-keyring-query acpi_call-dkms evince2 elementary-xfce-icons-git numix-themes-darkblue xfce-theme-greybird"
# arc-faenza-icon-theme"  

if [ "$TESTSYSTEM" != "YES" ]; then
	AUREXTRA=" pdftk-bin gitflow-avh  unetbootin mkv-extractor-qt"

  case $SETUP_MODE in
    workstation)
      AUREXTRA+=" gephi xvidcap gtk-theme-flatstudio dropbox jabref jdk jdk7 jdk6 jdk5 jdk-devel javafx-scenebuilder nextcloud-client yed"
      ;;
  esac

  AURPACKS+=$AUREXTRA
fi

PACKS="$PACKS"
AURPACKS="$AURPACKS"

pause "about to install all packages"

install_packs "$PACKS"

pause "packages installed; about to install aur packages;"

install_packs_aur "$AURPACKS"

pause "aur packages installed"

if [ "$TESTSYSTEM" != "YES" ]; then
	# install this one later on so that configure happens smoothly ...
	install_packs "texlive-lang"
fi

##########################
#######	  APPS	 #########
##########################

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/arch.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/terminator/arch.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/geany/arch.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/arch.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/arch.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/chrome/arch.sh

if [ "$TESTSYSTEM" != "YES" ]; then
	dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/firefox/arch.sh
	dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/truecrypt/arch.sh

  case $SETUP_MODE in
    workstation)
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/virtualbox/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/steam/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/purple-plugins/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/skype/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/hipchat/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/playonlinux/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/wine/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/arch.sh
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/gen-eclipse/arch.sh
      ;;
  esac
fi
#dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/acroread/arch.sh #disabled because crashing too often ...

pause "apps installed; configuring ..."

#########################
#######	 FIXES  #########
#########################

#fix python2 pkg 
#(cd /tmp/ && wget https://bootstrap.pypa.io/ez_setup.py -O - | python2)

#fix pulseaudio & skype mute
sed -i "s/load-module module-role-cork/#load-module module-role-cork/g" /etc/pulse/default.pa
sed -i "s/flat-volumes = no/flat-volumes = yes/g" /etc/pulse/daemon.conf

##########################
#######	 CONFIG  #########
##########################

case $SETUP_MODE in
	workstation)
		systemctl disable dhcpcd
		systemctl enable wicd
		systemctl enable lightdm
		systemctl enable tlp
		;;
esac

#keyboard configuration is done in xfce settings
#cp /usr/share/X11/xorg.conf.d/10-evdev.conf /etc/X11/xorg.conf.d/10-evdev.conf
#sed -i 's/MatchIsKeyboard "on"/MatchIsKeyboard "on"\n\tOption "XkbLayout"\t"fr"\n\tOption "XkbVariant"\t"latin9" /g' /etc/X11/xorg.conf.d/10-evdev.conf

retry "wget -q -O /etc/X11/xorg.conf.d/50-synaptics.conf ${SETUP_SCRIPT_LOCATION}/distros/archlinux/50-synaptics.conf"


#############################
#######	 X config   #########
#############################

cat >> /etc/X11/xorg.conf.d/10-keyboard-layout.conf << EOF
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
        Option "XkbVariant" "latin9"
EndSection
EOF

##############################
#######  PULSEAUDIO  #########
##############################

# see https://wiki.archlinux.org/index.php/Skype#Skype_sounds_stops_media_player_or_other_sound_sources
sed -i 's/load-module module-role-cork/#load-module module-role-cork/g' /etc/pulse/default.pa
sed -i 's/load-module module-udev-detect/load-module module-udev-detect tsched=0/g' /etc/pulse/default.pa
echo -e "\ndefault-fragments = 5\ndefault-fragment-size-msec = 2\n" >> /etc/pulse/daemon.conf

########################
#######	 WICD  #########
########################

mkdir -p /etc/wicd/encryption/templates/
cat > /etc/wicd/encryption/templates/eap-ttls << "EOF"
name = EAP-TTLS
author = IRISA
version = 1
require identity *Identity password *Password
optional ca_cert *Path_to_CA_Cert
protected password *Password
-----
ctrl_interface=/var/run/wpa_supplicant
network={
       ssid="$_ESSID"
       scan_ssid=$_SCAN
       key_mgmt=WPA-EAP
       eap=TTLS
       ca_cert="$_CA_CERT"
       phase2="auth=PAP"
       identity="$_IDENTITY"
       password="$_PASSWORD"
}
EOF
TEST=`cat /etc/wicd/encryption/templates/active | grep "eap-ttls" | wc -l`
[ "$TEST" == "0" ] && echo "eap-ttls" >> /etc/wicd/encryption/templates/active

cat > /etc/wicd/manager-settings.conf << EOF
[Settings]
always_show_wired_interface = True
use_global_dns = True
global_dns_1 = 8.8.8.8
global_dns_2 = 8.8.4.4
global_dns_3 = None
global_dns_dom = None
global_search_dom = None
auto_reconnect = True
debug_mode = 0
wired_connect_mode = 1
signal_display_type = 0
should_verify_ap = 1
dhcp_client = 0
link_detect_tool = 0
flush_tool = 0
sudo_app = 0
prefer_wired = True
show_never_connect = True

EOF

###################################
###### Notificatioin Sender #######
###################################

cat > /usr/local/bin/notifkoubi << "EOF"
#!/bin/bash

notify-send -u critical -i /usr/share/icons/elementary/emotes/16/face-cool.svg "*[ Koubi Notification ]*" "$@"
EOF

##############################
######## XDG Folders #########
##############################

mkdir -p /etc/xdg
cat > /etc/xdg/user-dirs.defaults << "EOF"
# Default settings for user directories
#
# The values are relative pathnames from the home directory and
# will be translated on a per-path-element basis into the users locale
DESKTOP=Desktop
DOWNLOAD=Desktop
TEMPLATES=.Templates
PUBLICSHARE=Public
DOCUMENTS=Desktop
MUSIC=Music
PICTURES=Desktop
VIDEOS=Desktop
# Another alternative is:
#MUSIC=Documents/Music
#PICTURES=Documents/Pictures
#VIDEOS=Documents/Videos
EOF

##############################
########### JAVA #############
##############################

case $SETUP_MODE in
  workstation)
    if [ "$TESTSYSTEM" != "YES" ]; then
      archlinux-java set java-8-openjdk
    fi
    ;;
esac

##############################
#######	 X startup   #########
##############################

echo "   X startup"
cat > /usr/local/bin/X_startup.sh << "EOF"
#!/bin/bash

## Condition, only run this script under Xfce
 if [ ! "$(pidof xfwm4)" ]; then
     exit 0
 fi

## Condition: Start xscreensaver, if required.
## note : not needed since there is a .desktop in /etc/xdg/autostart/
## in addition: causes a bug when 2 instances of xscreensaver are running
#if [ ! "$(pidof xscreensaver)" ]; then
#    xscreensaver -no-splash &
#fi

## numlock on by default
numlock on

## Condition: Start Conky after a slight delay
(
	sleep 10 &&
	CONKY_RUN=`ps -edf | grep conky | grep -v grep | wc -l` &&
	if [ "$CONKY_RUN" == "0" ]; then
		conky -c /etc/conky/koubi_conky.conf
	fi
) &
exit 0
EOF
chmod +x /usr/local/bin/X_startup.sh
cat > /etc/xdg/autostart/X_autostart.desktop << "EOF"
[Desktop Entry]
Name=X Services Autostart
Exec=/usr/local/bin/X_startup.sh
Terminal=false
Type=Application
EOF

cat > /usr/share/applications/chkboot_custom_alerts.desktop << EOF
[Desktop Entry]
Name=Chkboot Alerts
Exec=/usr/local/bin/chkboot_custom_alerts
Type=Application
StartupNotify=false
EOF
ln -s /usr/share/applications/chkboot_custom_alerts.desktop /etc/xdg/autostart/

pause "head installed;"



