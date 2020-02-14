#!/bin/bash

cat << EOF
   _____   __  __  ____ __  __  __  __
  / ___/  / / / / /  _/ \ \/ / / / / /
  \__ \  / /_/ /  / /    \  / / / / / 
 ___/ / / __  / _/ /     / / / /_/ /  
/____/ /_/ /_/ /___/    /_/  \____/   
仅支持Censos 7系统                                  
trojan+Nginx一键安装
本脚本会安装trojan+Nginx,并通过acme.sh自动更新伪装网站证书
通过魔改trojan官方脚本而成https://github.com/trojan-gfw/trojan
EOF

info(){
    echo -e "\033[32m提示: \033[0m$1"
}
error(){
    echo -e "\033[31m错误: \033[0m$1"
}
warning(){
    echo -e "\033[33m注意: \033[0m$1"
}

[[ $EUID -ne 0 ]] && error "请以root身份运行此脚本。" && exit 1

local_addr=`curl ipv4.icanhazip.com`
warning "本机IP: ${local_addr}"
read -p "输入绑定本机IP地址的域名: " url

real_addr=`ping ${url} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
warning "域名解析IP: ${real_addr}"

[[ ${real_addr} != ${local_addr} ]] && error "域名解析不到本服务器!" && exit 1

read -p "请设置Trojan链接密码: " trojan_passwd

function prompt() {
    while true; do
        read -p "$1 [y/N] " yn
        case $yn in
            [Yy] ) return 0;;
            [Nn]|"" ) return 1;;
        esac
    done
}

info "开始安装trojan..."
sleep 3

NAME="trojan"
VERSION="1.14.1"
TARBALL="${NAME}-${VERSION}-linux-amd64.tar.xz"
DOWNLOADURL="https://github.com/trojan-gfw/${NAME}/releases/download/v${VERSION}/${TARBALL}"
TMPDIR="$(mktemp -d)"
INSTALLPREFIX="/usr/local"
SYSTEMDPREFIX="/etc/systemd/system"

BINARYPATH="${INSTALLPREFIX}/${NAME}/${NAME}"
CONFIGPATH="${INSTALLPREFIX}/${NAME}/config.json"
SYSTEMDPATH="${SYSTEMDPREFIX}/${NAME}.service"

cd ${TMPDIR}

info "下载 ${NAME} ${VERSION}"
curl -LO --progress-bar ${DOWNLOADURL} || wget -q --show-progress ${DOWNLOADURL}

info "解压 ${NAME} ${VERSION}"
tar xf ${TARBALL}
cd ${NAME}

info "安装 ${NAME} ${VERSION} 到 ${BINARYPATH}"
install -Dm755 ${NAME} ${BINARYPATH}

if [[ -d ${SYSTEMDPREFIX} ]]; then
    info "安装 ${NAME} 系统服务到 ${SYSTEMDPATH}"
    if [[ ! -f ${SYSTEMDPATH} ]] || prompt "已存在系统服务 ${SYSTEMDPATH}, 覆盖?"; then
        cat > ${SYSTEMDPATH} << EOF
[Unit]
Description=Service For ${NAME}
Documentation=https://trojan-gfw.github.io/${NAME}/config https://trojan-gfw.github.io/${NAME}/
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service

[Service]
Type=simple
StandardError=journal
ExecStart=${BINARYPATH} ${CONFIGPATH}
ExecStop=/bin/kill -2 \$MAINPID
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=3s

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable ${NAME}.service
    else
        info "跳过安装系统服务 ${NAME}"
    fi
fi

info "安装trojan配置文件"
cat > ${CONFIGPATH} << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "${trojan_passwd}"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "${INSTALLPREFIX}/${NAME}/fullchain.cer",
        "key": "${INSTALLPREFIX}/${NAME}/private.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

rm -rf ${TMPDIR}

info "安装trojan完成"

info "安装Nginx"
sleep 3

cd ~
rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install -y nginx
systemctl enable nginx.service
systemctl start nginx.service
systemctl status firewalld > /dev/null 2>&1
if [ $? -eq 0 ]; then
    firewall-cmd --add-port=80/tcp --permanent
    firewall-cmd --add-port=80/udp --permanent
    firewall-cmd --add-port=443/tcp --permanent
    firewall-cmd --add-port=443/udp --permanent

    firewall-cmd --reload
           
    info "443 80 端口已开放"
fi


cd /usr/share/nginx/html/
rm -rf ./*
wget https://github.com/yi-shiyu/Other/raw/master/html5up.zip
wget https://github.com/trojan-gfw/igniter/releases/download/v0.1.0-pre-alpha11/app-release.apk
wget https://github.com/trojan-gfw/trojan/releases/download/v${VERSION}/trojan-${VERSION}-win.zip
  
yum install unzip -y
unzip html5up.zip
rm -f html5up.zip

info "安装Nginx完成"

info "申请https证书"

curl https://get.acme.sh | sh

~/.acme.sh/acme.sh --issue -d ${url} --webroot /usr/share/nginx/html/
~/.acme.sh/acme.sh --installcert -d ${url} --key-file ${INSTALLPREFIX}/${NAME}/private.key --fullchain-file ${INSTALLPREFIX}/${NAME}/fullchain.cer --reloadcmd "systemctl restart ${NAME}.service"

cat << EOF
++++++++++++++++++++++++

安装完成。

trojan配置文件位置${CONFIGPATH}
nginx网站目录位置/usr/share/nginx/html/

停止systemctl stop ${NAME}.service
启动systemctl start ${NAME}.service
重启systemctl restart ${NAME}.service

Windows客户端下载https://github.com/trojan-gfw/trojan/releases/download/v${VERSION}/trojan-${VERSION}-win.zip
备用下载https://${url}/trojan-${VERSION}-win.zip
官网下载https://github.com/trojan-gfw/trojan/releases

Android客户端下载https://github.com/trojan-gfw/igniter/releases/download/v0.1.0-pre-alpha11/app-release.apk
备用下载https://{$url}/app-release.apk

使用方法参见网址https://evlan.cc/archives/trojan-nginx.html

++++++++++++++++++++++++
EOF
