#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#install dep


curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

CODENAME=$(lsb_release -cs)
# temporary fix until docker releases focal repo
if [ "$CODENAME" == "focal" ]; then
    CODENAME="eoan"
fi

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   ${CODENAME} \
   stable"

apt update

apt remove -y docker docker-engine docker.io containerd runc
install_packs docker-ce docker-ce-cli containerd.io

pip3 install docker-compose

usermod -aG docker $USR

exit 0

