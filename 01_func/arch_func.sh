#!/bin/bash -eu

# retry the given command until it succeed.
# $1 : a command as string
function retry {
  echo "retry '$1'"
	[ "$LOGCNT" == "" ] && export LOGCNT=0
	LOGCNT=$((LOGCNT+1))
	LOGFILE="retry_mainlog_$LOGCNT.log"
	MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
  set +e
	$1 >> $LOGFILE 2>> $LOGFILE
	while [ "$?" != "0" ]; do
		echo $MSG
		sleep 5
		LOGCNT=$((LOGCNT+1))
		LOGFILE="retry_mainlog_$LOGCNT.log"
		MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
		$1 >> $LOGFILE 2>> $LOGFILE
	done
  set -e
}

function pause {
	if [ "$ENABLE_PAUSE" == "YES" ]; then
		read -p " [ Press Enter ] ... $@"
	else
		echo " [ Pause skiped ] ... $@"
	fi
}

function upgrade {
	echo "   Upgrade"
	pacman --noconfirm -Syu
}
function install_packs {
	PACKS=$@
	echo "   Installing packages [$PACKS]"
	[ "$PACKS" == "" ] && echo "Warning : package list is empty" && return
	if [ "$ENABLE_PAUSE" == "YES" ]; then
		for package in $PACKS; do
			#pause "pacman --noconfirm -S $package"
			retry "pacman --noconfirm -S $package"
		done
	else 
		retry "pacman --noconfirm -S $PACKS"
	fi
}

function upgrade_aur {
	echo "   Upgrade AUR"
	cd /tmp && su build -c "yaourt --noconfirm -Syu"
}
function install_packs_aur {
	PACKS=$@
	echo "   Installing AUR packages [$PACKS]"
	[ "$PACKS" == "" ] && echo "Warning : package list is empty" && return
	for package in $PACKS; do
		pause "yaourt --noconfirm -S $package"
		cd /tmp && su build -c "yaourt --noconfirm -S $package"
		RES=$?
		if [ "$RES" != "0" ]; then
			sleep 2
			cd /tmp && su build -c "yaourt --noconfirm -S $package"
			RES=$?
			if [ "$RES" != "0" ]; then
				echo -e "\nAn error occured during installation of \"$package\"\n"
				echo -e "command was 'cd /tmp && su build -c \"yaourt --noconfirm -S $package\"'"
				read -p "Press enter ..."
			fi
		fi
	done
}

function dl_and_execute {
	SCRIPT_LOCATION=$1
	SCRIPT_FILE=`mktemp --suffix=.sh`
	pause "dl and execute $1"
	retry "wget --no-cache -q -O ${SCRIPT_FILE} ${SCRIPT_LOCATION}"
	chmod +x ${SCRIPT_FILE}
	${SCRIPT_FILE}
	rm ${SCRIPT_FILE}
}
