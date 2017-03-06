#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

echo "   Geany"

PKGS="geany geany-plugins git geany-plugin*"

install_packs "$PKGS"

mkdir -p /etc/skel/.config/geany/
retry "wget -q -O /etc/skel/.config/geany/geany.conf ${SETUP_SCRIPT_LOCATION}/02_apps/geany/geany.conf"

#different path for ubuntu
sed -i -e 's#/usr/lib/geany/#/usr/lib/x86_64-linux-gnu/geany/#g' /etc/skel/.config/geany/geany.conf

git clone https://github.com/codebrainz/geany-themes.git geany-themes
cp -R geany-themes/colorschemes /usr/share/geany/
rm -rf geany-themes

exit 0

