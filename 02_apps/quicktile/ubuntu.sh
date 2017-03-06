#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#setup application
mkdir -p /etc/xdg/autostart/
mkdir -p /etc/quicktile/

apt-get -y install python python-gtk2 python-xlib python-dbus python-wnck git

git clone https://github.com/ssokolow/quicktile.git quicktile

cp quicktile/quicktile.py /usr/local/bin/quicktile.py
chmod 755 /usr/local/bin/quicktile.py

# add special script to link XDG config dir to /etc/quicktile
cat > /usr/local/bin/quicktile_startup.sh << EOF
#!/bin/bash
export XDG_CONFIG_HOME=/etc/quicktile/
/usr/local/bin/quicktile.py --daemonize
EOF
chmod +x /usr/local/bin/quicktile_startup.sh

retry "wget -q -O /etc/quicktile/quicktile.cfg ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/quicktile.cfg"
retry "wget -q -O /etc/xdg/autostart/quicktile.desktop ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/quicktile.desktop"

chmod +x /etc/xdg/autostart/quicktile.desktop

#cleaning
rm -rf ./quicktile/

exit

