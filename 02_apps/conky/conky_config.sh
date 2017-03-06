#!/bin/bash

# if script is run during post install script, load script location
if [ -e /setup.dat ]; then	
	#BG=`cat /setup.dat | sed '1q;d'`
	SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
	#TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
	#INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
else 
	SETUP_SCRIPT_LOCATION=http://home.koub.org/files/linux/
fi

CONFFILE=/etc/conky/koubi_conky.conf
CONFDIR=`dirname $CONFFILE`

# retry the given command until it succeed.
# $1 : a command as string
function retry {
	[ "$LOGCNT" == "" ] && export LOGCNT=0
	let LOGCNT++
	LOGFILE="retry_mainlog_$LOGCNT.log"
	MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
	$1 >> $LOGFILE 2>> $LOGFILE
	while [ "$?" != "0" ]; do
		echo $MSG
		sleep 5
		let LOGCNT++
		LOGFILE="retry_mainlog_$LOGCNT.log"
		MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
		$1 >> $LOGFILE 2>> $LOGFILE
	done
}

mkdir -p $CONFDIR
retry "wget $SETUP_SCRIPT_LOCATION/02_apps/conky/koubi_conky.conf -O $CONFFILE"
#retry "wget http://home.koub.org/files/linux/02_apps/conky/conky.conf -O $CONFFILE"

#PARTS=`mount | grep -v /sys | grep -v /proc | grep -v /run | grep -v tmpfs | grep -v cdrom | grep ^/`
PARTS=`cat /etc/fstab | grep -v "^#" | grep -v cdrom | grep -v swap | grep -v "//" | grep -v "[ \t]bind" | cut -d" " -f 2 | grep -v "^$"`
[ "$PARTS" == "" ] && PARTS=`cat /etc/fstab | grep -v "^#" | grep -v cdrom | grep -v swap | grep -v "//" | grep -v "[ \t]bind" | cut -f 2 | grep -v "^$"`
DISKS=`fdisk -l 2> /dev/null | grep Dis | grep -v mapper | grep /dev | grep -v "/dev/loo" | cut -d" " -f 2 | colrm 9 | colrm 1 5 | sort`
PRINTCONKY=

#####################
#######	LVM #########
#####################

LVS=`lvscan | cut -d"'" -f2`
VGS=`vgs | tail -n +2 | colrm 1 2 | cut -d" " -f 1`
PRINTCONKY=""
NEWPARTS=""
if [ "$LVS" != "" ]; then
	while read -r VG; do
		PRINTCONKY+="\${color grey}LVM Group ${color}$VG\${color grey} :\$color\n"
		I=0
		while read -r LV; do
			DMP=`ls -l $LV | cut -d">" -f 2`
			for PART in $PARTS; do
				MOUNTLINE=`mount | grep " $PART " | cut -d" " -f 1`
				MDMPCMD=`ls -l $MOUNTLINE | grep ">"`
				if [ "$MDMPCMD" != "" ]; then
					MDMP=`echo $MDMPCMD | cut -d">" -f 2`
					if [ "$MDMP" == "$DMP" ]; then
						let I++
						PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
					
					fi
				else 
					NEWPARTS+=" $PART"
				fi
			done
		done <<< "$LVS"
		
	done <<< "$VGS"

	if [ "$I" == "0" ]; then
		PRINTCONKY=${PRINTCONKY%??}
		PRINTCONKY+=" none.\n"
	fi
fi
PARTS=`echo $NEWPARTS | xargs -n1 | sort -u | xargs`

##############################
#######	 PARTITIONS  #########
##############################

for DISK in $DISKS; do
	PRINTCONKY+="\${color grey}File systems on \$color/dev/$DISK \${color grey}: \$color(\${color orange}I/O : \${diskio /dev/$DISK}/s\$color)\n"
	I=0
	for PART in $PARTS; do
		DEVICE=`mount | grep " $PART " | cut -d" " -f 1`
		if [ "`echo $DEVICE | grep /dev/mapper/`" != "" ]; then
			DEVICE=`cryptsetup status $(basename $DEVICE) | grep device | colrm 1 11`
		fi
		if [ "`echo $DEVICE | grep $DISK`" == "$DEVICE" ]; then
			PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
			let I++
		else
			UUIDPART=`ls -l /dev/disk/by-uuid/ | grep "$(basename $DEVICE)" | grep $DISK`
			if [ "$UUIDPART" != "" ]; then
				PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
				let I++
			fi
		fi
	done
	if [ "$I" == "0" ]; then
		PRINTCONKY=${PRINTCONKY%??}
		PRINTCONKY+=" none.\n"
	fi
done
PRINTCONKY=${PRINTCONKY%??}
sed -i -e "s#%%HDD%%#$PRINTCONKY#g" $CONFFILE

############################
#######	PROCESSORS #########
############################

NBPROC=`cat /proc/cpuinfo | grep processor | wc -l`
CPUS=" "
for (( i=1; i<=$NBPROC; i++ ))
do
	CPUS+="\${color grey}CPU0$i @\$color\${freq_g $i}\${color grey}GHz \${color}\${cpubar cpu$i 7,70}"
	if [[ "$((i % 2))" == "0" ]]; then
		CPUS+="\n "
	else
		CPUS+="\${alignr}"
	fi
done
if [ "$((NBPROC % 2))" == "0" ]; then
	CPUS=${CPUS%???}
else
	CPUS=${CPUS%?????????}
fi
sed -i -e "s#%%CPU%%#$CPUS#g" $CONFFILE

###########################
#######	 NETWORK  #########
###########################

NETDEVS=`ls /sys/class/net | grep -v "^lo$"`
NET=" "

for NETDEV in $NETDEVS; do
	NET+="\n\${if_up ${NETDEV}}"
	NET+="\${color red}NETWORK ${NETDEV^^} (\${addr ${NETDEV}}) \${hr 2}\$color\n"
	NET+=" \${color grey}Down: \$color\${downspeed ${NETDEV}}/s (\${totaldown ${NETDEV}})\${alignr}\${color grey}Up: \$color\${upspeed ${NETDEV}}/s (\${totalup ${NETDEV}})\n"
	NET+=" \${downspeedgraph ${NETDEV} 20,162 CCFF01 CCFF01}\$alignr\${upspeedgraph ${NETDEV} 20,162 FF4301 FF4301}\${else}"
	NET+="\${color red}NETWORK ${NETDEV^^} (DOWN) \${hr 2}\$color\${endif}"
done


sed -i -e "s#%%NET%%#$NET#g" $CONFFILE

exit 
