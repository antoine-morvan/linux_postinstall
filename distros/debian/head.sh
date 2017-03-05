#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Head Installation **"
echo ""

##########################
#######	 SETUP	 #########
##########################
#note: ffmpeg is in the multimedia repo, therefore installed later when adding specific repos

echo "   Downloading head packages"
PACKS="xorg lightdm terminator geany pulseaudio pulseaudio-utils pasystray pavucontrol paman paprefs pavumeter mate-themes wicd wicd-gtk xfce4 xfce4-goodies xfce4-artwork xfce4-session xfce4-settings xfwm4 xfwm4-themes xfconf thunar numlockx pinta qalculate evince arandr"

EXTRA=" system-config-printer icedove vlc pidgin xchat ario gparted filezilla xfburn mesa-utils gvfs* icedtea-7-plugin keepassx youtube-dl calibre"
EXTRA+=" libreoffice libreoffice-l10n-fr gimp inkscape xdot graphviz audacity avidemux faac"
EXTRA+=" texlive* jabref latex2rtf pdftk lyx texmaker pstotext openjdk-7-jdk golang ruby java-common g++ libtool pkg-config git-flow gitg maven gradle"
EXTRA+=" debian-reference" 

install_packs "$PACKS $EXTRA"


##########################
#######	  APPS	 #########
##########################

dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/xfce4_config.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/conky.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/quicktile.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/ffmpeg.sh
#dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/chrome.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/chromium.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/skype.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/iceweasel.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/acroread.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/virtualbox.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/truecrypt.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/wine.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/playonlinux.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/purple-facebook.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/hipchat.sh

#steam last because interactive
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/apps/steam.sh

##########################
#######	 LIGHTDM #########
##########################

# >> dont forget to install numlockx or lightdm will not work
echo "   Config LightDM"
sed -i -e "s#/usr/share/images/desktop-base/login-background.svg#$BG#g" /etc/lightdm/lightdm-gtk-greeter.conf
sed -i -e 's#Adwaita#Greybird#g' /etc/lightdm/lightdm-gtk-greeter.conf
sed -i -e 's/#xft-dpi=/xft-dpi=80/g' /etc/lightdm/lightdm-gtk-greeter.conf
sed -i -e 's%#greeter-setup-script=%greeter-setup-script=/usr/bin/numlockx on%g' /etc/lightdm/lightdm.conf


##############################
#######	 PULSEAUDIO  #########
##############################

# see https://wiki.archlinux.org/index.php/Skype#Skype_sounds_stops_media_player_or_other_sound_sources
sed -i 's/load-module module-role-cork/#load-module module-role-cork/g' /etc/pulse/default.pa
sed -i 's/load-module module-udev-detect/load-module module-udev-detect tsched=0/g' /etc/pulse/default.pa
echo -e "\ndefault-fragments = 5\ndefault-fragment-size-msec = 2\n" >> /etc/pulse/daemon.conf

##############################
#######	 TERMINATOR  #########
##############################

echo "   Terminator"
mkdir -p /etc/skel/.config/terminator/
cat >  /etc/skel/.config/terminator/config << "EOF"
[global_config]
  geometry_hinting = False
[keybindings]
[profiles]
  [[default]]
    background_darkness = 0.9
    background_type = transparent
    foreground_color = "#ffffff"
[plugins]
EOF


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

## Detect and configure touchpad. See 'man synclient' for more info.
if egrep -iq 'touchpad' /proc/bus/input/devices; then
    synclient VertEdgeScroll=1 &
    synclient TapButton1=1 &
fi

## Condition: Start xscreensaver, if required.
if [ ! "$(pidof xscreensaver)" ]; then
    xscreensaver -no-splash &
fi

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

cat > /etc/xdg/autostart/pasystray.desktop << "EOF"
[Desktop Entry]
Name=pasystray Autostart
Exec=/usr/bin/pasystray
Terminal=false
Type=Application
EOF


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


###################################
#######	File association  #########
###################################

echo "   File association"
mkdir -p /etc/skel/.config/
cat > /etc/skel/.config/mimeapps.list << "EOF"
[Default Applications]
application/x-shellscript=geany.desktop;
text/plain=geany.desktop
text/x-tex=geany.desktop
text/x-bibtex=geany.desktop
application/pdf=evince.desktop
application/xml=geany.desktop
image/png=pinta.desktop
image/tiff=pinta.desktop
image/bmp=pinta.desktop
image/jpeg=pinta.desktop
image/gif=pinta.desktop

EOF
