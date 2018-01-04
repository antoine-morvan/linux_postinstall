#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#setup application

echo ""
echo "** Setup Conky"
echo ""

upgrade
install_packs lvm2 conky-all

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/conky_config.sh

##############################
#####  Conky startup   #######
##############################

echo "   Conky startup"
cat > /usr/local/bin/conky_startup.sh << "EOF"
#!/bin/bash

## Condition, only run this script under Xfce
if [ ! "$(pidof xfwm4)" ]; then
	exit 0
fi

## Condition: Start Conky after a slight delay
(
	sleep 10 &&
	CONKY_RUN=`ps -edf | grep conky | grep -v grep | grep -v startup | wc -l` &&
	if [ "$CONKY_RUN" == "0" ]; then
		conky -c /etc/conky/koubi_conky.conf
	fi
) &
exit 0
EOF
chmod +x /usr/local/bin/conky_startup.sh
cat > /etc/xdg/autostart/conky_startup.desktop << "EOF"
[Desktop Entry]
Name=Conky Autostart
Exec=/usr/local/bin/conky_startup.sh
Terminal=false
Type=Application
EOF
chmod +x /etc/xdg/autostart/conky_startup.desktop

exit 0
