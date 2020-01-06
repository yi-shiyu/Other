#!/bin/bash

cat << EOF
   _____   __  __  ____ __  __  __  __
  / ___/  / / / / /  _/ \ \/ / / / / /
  \__ \  / /_/ /  / /    \  / / / / / 
 ___/ / / __  / _/ /     / / / /_/ /  
/____/ /_/ /_/ /___/    /_/  \____/   
                                  
EOF

echo "Welcome to SSH Key Installer"

url=$1

if [[ -z $1 ]]; then
    echo 'Input key download url'
    read url
fi

while true; do
    echo -n "Disable password login?(Y/N)"
    read pass
    if [[ ${pass} != "y" && ${pass} != "Y" && ${pass} != "N" && ${pass} != "n" ]]; then
        echo -n "Bad answer! Please only input Y or N"
    else
        break
    fi
done


DISABLE_PW_LOGIN=0

if [[ "${pass}" == "y" || "${pass}" == "Y" ]]; then
    DISABLE_PW_LOGIN=1
fi

#check if we are root
if [ $EUID -ne 0 ]; then
    echo 'Error: you need to be root to run this script'; exit 1;
fi

if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
    echo "Info: ~/.ssh/authorized_keys is missing ...";

    echo "Creating ${HOME}/.ssh/authorized_keys ..."
    mkdir -p ${HOME}/.ssh/
    touch ${HOME}/.ssh/authorized_keys

    if [ ! -f "${HOME}/.ssh/authorized_keys" ]; then
        echo "Failed to create SSH key file"
    else
        echo "Key file created, proceeding..."
    fi
fi

#get key from server
curl -DL /tmp/headers.txt ${url} >/tmp/key.txt >> /dev/null 2>&1 &
HTTP_CODE=$(sed -n 's/HTTP\/1\.[0-9] \([0-9]\+\).*/\1/p' /tmp/headers.txt | tail -n 1)
if [ $HTTP_CODE -ne 200 ]; then
    echo "Error: download server error"; exit 1;
fi

PUB_KEY=$(cat /tmp/key.txt)


if [ $(grep -m 1 -c "${PUB_KEY}" ${HOME}/.ssh/authorized_keys) -eq 1 ]; then
    echo 'Warning: Key is already installed'; exit 1;
fi

#install key
echo -e "\n${PUB_KEY}\n" >> ${HOME}/.ssh/authorized_keys
rm -f /tmp/key.txt
rm -f /tmp/headers.txt
echo 'Key installed successfully'

#disable root password
if [ ${DISABLE_PW_LOGIN} -eq 1 ]; then
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
    echo 'Disabled password login in SSH'
    echo 'Restart SSHd!'
    service sshd restart
fi
