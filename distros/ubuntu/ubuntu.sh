#!/bin/bash
# from ubuntu 16.04.2 amd64 desktop 
# run as sudo

###
### instantané 1
###

[ `whoami` != root ] && echo "should run as root" && exit 1


#configure proxy for installation...
#test if local server is present
ping -c 1 -i 0.2 gw.diablan 2> /dev/null
PINGRESULT=$?
if [ "$PINGRESULT" == "0" ]; then
	#use local url
	export SETUP_SCRIPT_LOCATION=http://gw.diablan/files/linux/
else
	#use remote url
	export SETUP_SCRIPT_LOCATION=http://home.koub.org/files/linux/
fi

#utility functions
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#update source.list

echo "deb http://archive.canonical.com/ubuntu xenial partner" >> /etc/source.list
echo "deb-src http://archive.canonical.com/ubuntu xenial partner" >> /etc/source.list


#do a full upgrade
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove
apt-get -y clean


FOUND_VBOX=`lspci | grep -i vga | grep -i virtualbox | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	#explicit replacement of wayland with xorg beforehand
	apt-get -y install xserver-xorg xserver-xorg-video-all
	apt-get -y install virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
else
	echo "VirtualBox not found"
fi

#remove amazon app. FFS
apt-get -y remove unity-webapps-common

#install various tools
apt-get -y install htop geany bwm-ng qalculate-gtk filezilla vlc

###
### instantané 2
###

exit



#deadfbeef
add-apt-repository -y ppa:starws-box/deadbeef-player
apt-get update
apt-get -y install deadbeef
wget http://home.koub.org/files/linux/ubuntu/ddb_misc_filebrowser_GTK2.so -O /usr/lib/deadbeef/ddb_misc_filebrowser_GTK2.so
mkdir -p /etc/skel/.config/deadbeef/
cat > /etc/skel/.config/deadbeef/config << "EOF"
close_send_to_tray 1

gtkui.eq.visible 1
gtkui.layout.0.6.2 vbox expand="0 1" fill="1 1" homogeneous=0 {hbox expand="0 1 0" fill="1 1 1" homogeneous=0 {playtb {} seekbar {} volumebar {} } hsplitter pos=355 locked=0 {filebrowser {} hsplitter pos=434 locked=0 {tabbed_playlist hideheaders=0 width=434 {} vsplitter pos=169 locked=0 {coverart {} selproperties {} } } } } 
gtkui.columns.playlist [{"title":"♫","id":"1","format":"%playstatus%","size":"50","align":"0","color_override":"0","color":"#ff000000"},{"title":"Artiste / Album","id":"-1","format":"%artist% - %album%","size":"150","align":"0","color_override":"0","color":"#ff000000"},{"title":"N° piste","id":"-1","format":"%tracknumber%","size":"50","align":"1","color_override":"0","color":"#ff000000"},{"title":"Titre","id":"-1","format":"%title%","size":"150","align":"0","color_override":"0","color":"#ff000000"},{"title":"Durée","id":"-1","format":"%length%","size":"50","align":"0","color_override":"0","color":"#ff000000"},{"title":"Bandwidth","id":"-1","format":"%samplerate%Hz - %bitrate%kb/s - %channels%","size":"100","align":"0","color_override":"0","color":"#ffd0d0d0"}]

mainwin.geometry.h 600
mainwin.geometry.w 1000
mainwin.geometry.x 40
mainwin.geometry.y 40

filebrowser.autofilter 1
filebrowser.bgcolor 
filebrowser.bgcolor_selected 
filebrowser.coverart_files cover.png;cover.jpg;folder.png;folder.jpg;front.png;front.jpg
filebrowser.coverart_scale 1
filebrowser.coverart_size 24
filebrowser.defaultpath $HOME/Musique
filebrowser.enabled 1
filebrowser.expanded_rows 
filebrowser.extra_bookmarks $HOME/.config/deadbeef/bookmarks
filebrowser.fgcolor 
filebrowser.fgcolor_selected 
filebrowser.filter 
filebrowser.filter_enabled 1
filebrowser.font_size 0
filebrowser.fullsearch_wait 5
filebrowser.hidden 0
filebrowser.hide_navigation 0
filebrowser.hide_search 0
filebrowser.hide_toolbar 1
filebrowser.icon_size 24
filebrowser.save_treeview 1
filebrowser.search_delay 1000
filebrowser.show_coverart 1
filebrowser.showbookmarks 0
filebrowser.showhidden 0
filebrowser.showicons 1
filebrowser.sidebar_width 220
filebrowser.sort_treeview 1
filebrowser.treelines 0

cli_add_playlist_name Default
cli_add_to_specific_playlist 1

gtkui.hide_remove_from_disk 1

gtkui.mmb_delete_playlist 1
gtkui.name_playlist_from_folder 1

playlist.stop_after_album_reset 1
playlist.stop_after_current_reset 1

resume_last_session 1

playback.volume -28.57142
playback.order 2

alsa.freeonstop 1
alsa.resample 0
alsa_soundcard pulse

hotkey.key01 "Ctrl f" 0 0 find
hotkey.key02 "Ctrl o" 0 0 open_files
hotkey.key03 "Ctrl q" 0 0 quit
hotkey.key04 "Ctrl n" 0 0 new_playlist
hotkey.key05 "Ctrl a" 0 0 select_all
hotkey.key06 "Escape" 0 0 deselect_all
hotkey.key07 "Ctrl m" 0 0 toggle_stop_after_current
hotkey.key08 "Ctrl j" 0 0 jump_to_current_track
hotkey.key09 "F1" 0 0 help
hotkey.key10 "Delete" 1 0 remove_from_playlist
hotkey.key11 "Ctrl w" 0 0 remove_current_playlist
hotkey.key12 "Return" 0 0 play
hotkey.key13 "n" 0 0 next
hotkey.key14 "q" 1 0 add_to_playback_queue
hotkey.key15 "Ctrl p" 0 0 preferences
hotkey.key16 "Ctrl Super p" 0 1 play_pause
hotkey.key17 "Ctrl Super o" 0 1 seek_5p_fwd
hotkey.key18 "Ctrl Super i" 0 1 seek_5p_back
hotkey.key19 "Ctrl Super Next" 0 1 next
hotkey.key20 "Ctrl Super Prior" 0 1 prev
hotkey.key21 "Ctrl Super c" 0 1 stop
hotkey.key22 "Ctrl Super Down" 0 1 volume_down
hotkey.key23 "Ctrl Super Up" 0 1 volume_up
hotkey.key24 "Ctrl Super space" 0 1 toggle_mute

EOF


#désactiver les sons

#installer xfce4

