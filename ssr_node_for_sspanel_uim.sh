#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

cat << EOF

███████╗ ██╗  ██╗ ██╗ ██╗   ██╗ ██╗   ██╗
██╔════╝ ██║  ██║ ██║ ╚██╗ ██╔╝ ██║   ██║
███████╗ ███████║ ██║  ╚████╔╝  ██║   ██║
╚════██║ ██╔══██║ ██║   ╚██╔╝   ██║   ██║
███████║ ██║  ██║ ██║    ██║    ╚██████╔╝
╚══════╝ ╚═╝  ╚═╝ ╚═╝    ╚═╝     ╚═════╝ 

Modify: Shiyu

EOF

echo "Shadowsocksr server installation script for CentOS 7 x64"
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script!"; exit 1; }

read_parameter(){
    echo "Please input service name."
    read shadowsocks_path
    echo "Checking if there any exist Shadowsocksr server software..."
    if [[ -d "/usr/local/${shadowsocks_path}" ]]; then
        echo "/usr/local/${shadowsocks_path} is existed."
        exit 0
    fi
    

    echo -e "Please select the way your node server connection method:"
    echo -e "\t1. WebAPI"
    echo -e "\t2. Remote Database"
    read -p "Please input a number:(Default 2 press Enter) " connection_method
    while true; do
        [ -z ${connection_method} ] && connection_method=2
        if [[ ! ${connection_method} =~ ^[1-2]$ ]]; then
            echo "Bad answer! Please only input number 1~2"
        else
            break
        fi
    done

    if [[ ${connection_method} == '1' ]]; then
        echo -n "Please enter WebAPI url:"
        read webapi_url
        echo -n "Please enter WebAPI token:"
        read webapi_token
        echo -n "Server node ID:"
        read node_id
    elif [[ ${connection_method} == '2' ]]; then
        echo -n "Please enter DB server's IP address:"
        read db_ip
        echo -n "DB name:"
        read db_name
        echo -n "DB username:"
        read db_user
        echo -n "DB password:"
        read db_password
        echo -n "Server node ID:"
        read node_id
    fi

    while true; do
        echo -n "Do you want to enable multi user in single port feature?(Y/N)"
        read is_mu
        if [[ ${is_mu} != "y" && ${is_mu} != "Y" && ${is_mu} != "N" && ${is_mu} != "n" ]]; then
            echo -n "Bad answer! Please only input number Y or N"
        else
            if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
                echo -n "Please enter MU_SUFFIX:"
                read mu_suffix
                echo -n "Please enter MU_REGEX:"
                read mu_regex
            fi
            break
        fi
    done

    while true; do
        echo -n "Do you want to enable BBR feature(from mainline kernel) and optimizate the system?(Y/N)"
        read is_bbr
        if [[ ${is_bbr} != "y" && ${is_bbr} != "Y" && ${is_bbr} != "N" && ${is_bbr} != "n" ]]; then
          echo -n "Bad answer! Please only input number Y or N"
      else
          break
      fi
    done

    while true; do
        echo -n "Do you want to register SSR Node as system service?(Y/N)"
        read is_service
        if [[ ${is_service} != "y" && ${is_service} != "Y" && ${is_service} != "N" && ${is_service} != "n" ]]; then
            echo -n "Bad answer! Please only input number Y or N"
        else
            if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
                cat << EOF
===============================================================
Start Service: systemctl start ${shadowsocks_path}
---------------------------------------------------------------
Automatic Start: systemctl enable ${shadowsocks_path}
---------------------------------------------------------------
Stop  Service: systemctl stop ${shadowsocks_path}
---------------------------------------------------------------
Disable automatic start: systemctl disable ${shadowsocks_path}
===============================================================

The first and second options are automatically executed after the script is completed!

EOF
            fi
            break
        fi
    done
}

install_ssr(){
    echo "Press Y for continue the installation process, or press any key else to exit."
    read answer
    if [[ "${answer}" != "y" && "${answer}" != "Y" ]]; then
        echo -e "Installation has been canceled."
        exit 0
    fi
    echo "Install necessary package..."
    yum install epel-release unzip python-setuptools -y
    echo "Disabling firewalld..."
    systemctl stop firewalld && systemctl disable firewalld
    echo "Set time..."
    rm -rf /etc/localtime
    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    /sbin/hwclock --systoh
    echo "Installing Shadowsocksr server from GitHub..."
    cd /tmp && wget https://github.com/yi-shiyu/Other/raw/master/shadowsocks-manyuser.zip && unzip shadowsocks-manyuser.zip && mv shadowsocks-manyuser ${shadowsocks_path}
    mv -f ${shadowsocks_path} /usr/local
    cd /usr/local/${shadowsocks_path}
    yum install libsodium -y
    easy_install pip
    pip install --upgrade pip setuptools
    pip install -r requirements.txt
    echo "Generating config file..."
    chmod +x *.sh
    chmod +x shadowsocks/*.sh
    cp apiconfig.py userapiconfig.py
    cp config.json user-config.json
}

configuration_service(){
    echo "Writting system config..."
    echo
    cat > ${shadowsocks_path}.service << EOF
    [Unit]
    Description=SSR Node Service for SSPanel-Uim
    After=rc-local.service

    [Service]
    Type=simple
    User=root
    Group=root
    ExecStart=/usr/bin/nohup /usr/bin/python /usr/local/${shadowsocks_path}/server.py m>> /usr/local/${shadowsocks_path}/ssr_node.log 2>&1 &
    ExecStop=/usr/bin/bash /usr/local/${shadowsocks_path}/stop.sh
    Restart=always
    LimitNOFILE=512000

    [Install]
    WantedBy=multi-user.target
EOF
    chmod 754 ${shadowsocks_path}.service && mv ${shadowsocks_path}.service /usr/lib/systemd/system
    echo "Starting SSR Node Service..."
    systemctl enable ${shadowsocks_path} && systemctl start ${shadowsocks_path}
}

configuration_ssr(){
    if [[ ${connection_method} == '1' ]]; then
        echo "Writting connection config..."
        sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s%WEBAPI_URL = 'https://zhaoj.in'%WEBAPI_URL = '${webapi_url}'%g" -e "s/WEBAPI_TOKEN = 'glzjin'/WEBAPI_TOKEN = '${webapi_token}'/g" userapiconfig.py
    elif [[ ${connection_method} == '2' ]]; then
        sed -i -e "s/'modwebapi'/'glzjinmod'/g" userapiconfig.py
        echo "Writting connection config..."
        sed -i -e "s/NODE_ID = 0/NODE_ID = ${node_id}/g" -e "s/MYSQL_HOST = '127.0.0.1'/MYSQL_HOST = '${db_ip}'/g" -e "s/MYSQL_USER = 'ss'/MYSQL_USER = '${db_user}'/g" -e "s/MYSQL_PASS = 'ss'/MYSQL_PASS = '${db_password}'/g" -e "s/MYSQL_DB = 'shadowsocks'/MYSQL_DB = '${db_name}'/g" userapiconfig.py
    fi

    if [[ ${is_mu} == "y" || ${is_mu} == "Y" ]]; then
        echo "Writting MU config..."
        sed -i -e "s/MU_SUFFIX = 'zhaoj.in'/MU_SUFFIX = '${mu_suffix}'/g" -e "s/MU_REGEX = '%5m%id.%suffix'/MU_REGEX = '${mu_regex}'/g" userapiconfig.py
    fi
}

configuration_bbr(){
    wget https://shiyu.pro/BBR && bash BBR
}


run(){
    read_parameter
    install_ssr
    configuration_ssr
    if [[ ${is_service} == "y" || ${is_service} == "Y" ]]; then
        configuration_service
    fi
    if [[ ${is_bbr} == "y" || ${is_bbr} == "Y" ]]; then
        configuration_bbr
    fi
}

run
