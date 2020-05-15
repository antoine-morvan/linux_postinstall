
##### reporté ds le script, à valider


##### fait, à reporter dans le script de postinstall


##### solution easy, todo

add in bashrc:
```
PROMPT_COMMAND=__prompt_command # Func to gen PS1 after CMDs

__prompt_command() {
    local EXIT="$?"             # This nee
    DATE=$(date '+%Y-%m-%d %H:%M:%S,+%3N')
    PS1=""

    local RCol='\[\e[0m\]'

    local Red='\[\e[0;31m\]'
    local Gre='\[\e[0;32m\]'
    local BYel='\[\e[1;33m\]'
    local BBlu='\[\e[1;34m\]'
    local Pur='\[\e[0;35m\]'

    if [ $EXIT != 0 ]; then
        PS1+="${Red}${DATE} - \u${RCol}"      # Add red if exit code non 0
    else
        PS1+="${Gre}${DATE} - \u${RCol}"
    fi
    PS1+="${RCol}@${BBlu}\h ${Pur}\W${BYel}$ ${RCol}"
}

```
##### à trouver une solution


[UBUNTU] ajouter signal: https://signal.org/fr/download/
[UBUNTU] virer la notif HDDTemp ...

utiliser blkid pour détecter les differents types de volumes ...
 - blkid -t TYPE=crypto_LUKS

ajouter mkvtoolnix & mkvextract (ubuntu)

##### done & validated #####

[UBUNTU] Desactiver HDDTemp
[UBUNTU] Virer GDM3 & ubuntu desktop
[UBUNTU] Auto select user (end of main script)
[Ubuntu] virer desktop ubuntu
[UBUNTU] Install docker (https://docs.docker.com/install/linux/docker-ce/ubuntu/)
[UBUNTU] Install docker-compose (via pip3)
[UBUNTU] Set user in docker group
[ubuntu] full unattended install
[ubuntu] steam/wine specif scripts
[UBUNTU] verif launcher chrome
[ubuntu] racourcis steam
[UBUNTU] Set default background

