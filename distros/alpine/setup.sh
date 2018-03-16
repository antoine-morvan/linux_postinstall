#!/bin/ash -eu

# run as sudo

FASTSETUP=NO

###
### Checks
###

[ `whoami` != root ] && echo "should run as root" && exit 1


#configure proxy for installation...
#test if local server is present
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export ENABLE_PAUSE=NO
export LOGCNT=0

apk update
apk upgrade
apk add wget curl

#utility functions
[ ! -e alpine_func.sh ] &&  wget --no-cache -q ${SETUP_SCRIPT_LOCATION}/01_func/alpine_func.sh -O alpine_func.sh
source alpine_func.sh


