#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="jenkins"
AURPKGS=""

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

CONFFILE=/etc/conf.d/jenkins
JENKINS_PORT=9080

cat ${CONFFILE} | sed -e "s/\(JENKINS_PORT=--httpPort=\).*/\1${JENKINS_PORT}/g" > tmp
mv tmp ${CONFFILE}

#systemctl enable jenkins.service

exit
