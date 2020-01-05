#!/bin/bash
set -euo pipefail

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

local_addr=`curl ipv4.icanhazip.com`
echo '本机IP:' $local_addr
echo '输入绑定本机IP地址的域名'
read url
real_addr=`ping ${url} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
echo '域名解析IP:' $real_addr
if [[ $real_addr != $local_addr ]] ; then
    echo '域名解析失败!'
    exit 1
fi
echo '输入trojan连接密码'
read trojan_passwd

function prompt() {
    while true; do
        read -p "$1 [y/N] " yn
        case $yn in
            [Yy] ) return 0;;
            [Nn]|"" ) return 1;;
        esac
    done
}

if [[ $(id -u) != 0 ]]; then
    echo Please run this script as root.
    exit 1
fi

echo '安装trojan'
sleep 1

NAME=trojan
VERSION=1.14.0
TARBALL="$NAME-$VERSION-linux-amd64.tar.xz"
DOWNLOADURL="https://github.com/trojan-gfw/$NAME/releases/download/v$VERSION/$TARBALL"
TMPDIR="$(mktemp -d)"
INSTALLPREFIX=/usr/local
SYSTEMDPREFIX=/etc/systemd/system

BINARYPATH="$INSTALLPREFIX/$NAME/$NAME"
CONFIGPATH="$INSTALLPREFIX/$NAME/config.json"
SYSTEMDPATH="$SYSTEMDPREFIX/$NAME.service"

cd "$TMPDIR"

echo '下载' $NAME $VERSION
curl -LO "$DOWNLOADURL" || wget "$DOWNLOADURL"

echo '解压' $NAME $VERSION
tar xf "$TARBALL"
cd "$NAME"

echo '安装' $NAME $VERSION '到' $BINARYPATH
install -Dm755 "$NAME" "$BINARYPATH"

if [[ -d "$SYSTEMDPREFIX" ]]; then
    echo '安装' $NAME '系统服务到' $SYSTEMDPATH
    if ! [[ -f "$SYSTEMDPATH" ]] || prompt "已存在系统服务 $SYSTEMDPATH, 覆盖?"; then
        cat > "$SYSTEMDPATH" << EOF
[Unit]
Description=$NAME
Documentation=https://trojan-gfw.github.io/$NAME/config https://trojan-gfw.github.io/$NAME/
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service

[Service]
Type=simple
StandardError=journal
ExecStart="$BINARYPATH" "$CONFIGPATH"
ExecReload=/bin/kill -HUP \$MAINPID

[Install]
WantedBy=multi-user.target
EOF
    else
        echo '跳过安装系统服务' $NAME
    fi
fi

rm -rf "$TMPDIR"

echo '安装trojan完成'

echo '安装Nginx'
sleep 1

cd ~
rpm -Uvh http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm
yum install -y nginx
systemctl enable nginx.service
systemctl start nginx.service
systemctl stop firewalld
systemctl disable firewalld

cd /usr/share/nginx/html/
rm -rf ./*
wget https://github.com/yi-shiyu/Other/raw/master/html5up.zip
wget https://github.com/trojan-gfw/igniter/releases/download/v0.1.0-pre-alpha11/app-release.apk
wget https://github.com/trojan-gfw/trojan/releases/download/v1.14.0/trojan-1.14.0-win.zip
yum install unzip -y
unzip html5up.zip
rm -f html5up.zip

echo '安装Nginx完成'

echo '申请https证书'
sleep 1

curl https://get.acme.sh | sh

~/.acme.sh/acme.sh --issue -d $url --webroot /usr/share/nginx/html/
systemctl stop nginx.service
~/.acme.sh/acme.sh --installcert -d $url \
--key-file $INSTALLPREFIX/$NAME/private.key \
--fullchain-file $INSTALLPREFIX/$NAME/fullchain.cer \
--reloadcmd "systemctl force-reload nginx.service"

echo '安装trojan配置文件'
cat > $CONFIGPATH << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "$trojan_passwd"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "$INSTALLPREFIX/$NAME/fullchain.cer",
        "key": "$INSTALLPREFIX/$NAME/private.key",
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

systemctl start trojan.service
systemctl enable trojan.service

cat << EOF
++++++++++++++++++++++++

安装完成。

trojan配置文件位置$CONFIGPATH
nginx网站目录位置/usr/share/nginx/html/

停止systemctl stop trojan
启动systemctl start trojan

Windows客户端下载https://github.com/trojan-gfw/trojan/releases/download/v1.14.0/trojan-1.14.0-win.zip
备用下载https://$url/trojan-1.14.0-win.zip

Android客户端下载https://github.com/trojan-gfw/igniter/releases/download/v0.1.0-pre-alpha11/app-release.apk
备用下载https://$url/app-release.apk

使用方法参见网址https://evlan.cc/archives/trojan-nginx.html

++++++++++++++++++++++++
EOF
