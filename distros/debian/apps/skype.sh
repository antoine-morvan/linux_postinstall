#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Skype"
echo ""


retry "wget -q -O /tmp/skype-install.deb http://www.skype.com/go/getskype-linux-deb"
dpkg -i /tmp/skype-install.deb 2> /dev/null > /dev/null
retry "apt-get -f -y -q -d install"
apt-get -f -y -q install 2> /dev/null > /dev/null
rm /tmp/skype-install.deb
