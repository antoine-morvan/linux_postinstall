#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Steam"
echo ""


update
upgrade
install_packs "libcurl3:i386"

retry "apt-get -y -q -d install steam"
apt-get -y -q install steam
RES=$?
if [ $RES != 0 ]; then
	apt-get -y -q -f install
	#go back to interactive frontend to accept steam licence
	unset DEBIAN_FRONTEND
	apt-get -y install steam
	export DEBIAN_FRONTEND=noninteractive
fi
