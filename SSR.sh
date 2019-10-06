#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH


Green_font="\033[32m"
Red_font="\033[31m"
Red_background="\033[41;37m"
color_end="\033[0m"

Error="${Red_font}错误${color_end}: "路径
Info="${Green_font}提示${color_end}: "

[[ $EUID -ne 0 ]] && echo -e "${Error}你必须以root身份运行这个脚本！" && exit 1

cur_dir=$( pwd )

uninstall_shadowsocks() {
        if [ -f ${shadowsocks_r_init} ]; then
            uninstall_shadowsocks_r
        else
            echo
            echo -e "${Error}ShadowsocksR未用此脚本安装，无法卸载！"
            echo
            exit 1
        fi
}

uninstall_shadowsocks_r() {
    echo
    echo -e "${Info}你确定卸载${Red_font}ShadowsocksR${color_end}? [y/n]\n"
    read -p "(default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ${shadowsocks_r_init} status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo
            ${shadowsocks_r_init} stop
        fi
        local service_name=$(basename ${shadowsocks_r_init})
        if check_sys packageManager yum; then
            chkconfig --del ${service_name}
        elif check_sys packageManager apt; then
            update-rc.d -f ${service_name} remove
        fi
        rm -rf $(dirname ${shadowsocks_r_config})
        rm -f ${shadowsocks_r_init}
        rm -f /var/log/shadowsocks.log
        rm -rf /usr/local/shadowsocks
        rm -f /bin/SSR
        echo
        echo -e "${Info}ShadowsocksR卸载完成！"
        echo
    else
        echo
        echo -e "${Info}ShadowsocksR卸载取消…"
        echo
    fi
}

install_logo() {
    clear
    echo -e "\n==================================\n\n\t${Green_font}ShadowsocksR一键脚本${color_end}.\n\n整理:${Red_background}shiyu${color_end}\tThanks:BreakWa11\n\n=================================="
}

install_shadowsocks() {
    disable_selinux
    install_select
    install_prepare
    install_dependencies
    download_files
    config_shadowsocks
    if check_sys packageManager yum; then
        config_firewall
    fi
    install_main
    install_cleanup
}

disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

install_select() {
    if ! install_check; then
        echo -e "${Error}不支持你的系统！"
        echo -e "请更换系统: CentOS 6+/Debian 7+/Ubuntu 12+"
        exit 1
    fi

    clear
}

install_check() {
    if check_sys packageManager yum || check_sys packageManager apt; then
        if centosversion 5; then
            return 1
        fi
        return 0
    else
        return 1
    fi
}

check_sys() {
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [ -f /etc/redhat-release ]; then
        release="centos"
        systemPackage="yum"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
    fi

    if [ ${checkType} == "sysRelease" ]; then
        if [ "$value" == "$release" ]; then
            return 0
        else
            return 1
        fi
    elif [ ${checkType} == "packageManager" ]; then
        if [ "$value" == "$systemPackage" ]; then
            return 0
        else
            return 1
        fi
    fi
}


check_datetime(){
    	rm -rf /etc/localtime
	    ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	    ntpdate 1.cn.pool.ntp.org
}


install_prepare() {
    install_logo
    install_prepare_password
    install_prepare_port
    install_prepare_cipher
    install_prepare_protocol
    install_prepare_obfs

    echo
    echo -e "${Info}按任意键开始搭建...或者按 Ctrl+C 取消。"
    char=`get_char`

}

get_char() {
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

install_libsodium() {
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
        download "${libsodium_file}.tar.gz" "${libsodium_url}"
        tar zxf ${libsodium_file}.tar.gz
        cd ${libsodium_file}
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "${Error}${libsodium_file} 安装失败！"
            install_cleanup
            exit 1
        fi
    else
        echo -e "${Info}${libsodium_file} 已被提前安装。"
        echo
    fi
}

install_prepare_password() {
    echo
    sleep 1
    echo -e "${Info}请设置ShadowsocksR的密码"
    echo
    read -p "(回车默认密码: shiyu):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="shiyu"
    echo
    echo
    echo -e "==================="
    echo
    echo -e "密码: ${Red_font}${shadowsockspwd}${color_end}"
    echo
    echo -e "==================="
    echo
    echo
}

install_prepare_port() {
    while true
    do
    sleep 1
    echo -e "${Info}请设置ShadowsocksR的远程连接端口: [1-65535]"
    read -p "(回车默认端口: 8388):" shadowsocksport
    [ -z "${shadowsocksport}" ] && shadowsocksport="8388"
    expr ${shadowsocksport} + 1 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ] && [ ${shadowsocksport:0:1} != 0 ]; then
            echo
            echo
            echo -e "==================="
            echo
            echo -e "远程端口: ${Red_font}${shadowsocksport}${color_end}"
            echo
            echo -e "==================="
            echo
            echo
            break
        fi
    fi
    echo
    echo -e "${Error}请输入正确的端口号，范围: 1~65535"
    echo
    done
}

install_prepare_cipher() {
    while true
    do
    echo
    sleep 1
    echo -e "${Info}请选择ShadowsocksR的加密方法"
    echo
        for ((i=1;i<=${#r_ciphers[@]};i++ )); do
            hint="${r_ciphers[$i-1]}"
            echo -e "  ${Red_font}${i}${color_end}: ${hint}"
        done
        echo
        read -p "(回车默认: ${r_ciphers[0]}):" pick
        [ -z "$pick" ] && pick=1
        expr ${pick} + 1 &>/dev/null
        if [ $? -ne 0 ]; then
            echo
            echo -e "${Error}请输入正确的数字!"
            echo
            continue
        fi
        if [[ "$pick" -lt 1 || "$pick" -gt ${#r_ciphers[@]} ]]; then
            echo
            echo -e "${Error}数字范围: 1~${#r_ciphers[@]}"
            echo
            continue
        fi
        shadowsockscipher=${r_ciphers[$pick-1]}
    echo
    echo -e "==================="
    echo
    echo -e "加密方法 = ${Red_font}${shadowsockscipher}${color_end}"
    echo
    echo -e "==================="
    echo
    break
    done
}

install_prepare_protocol() {
    while true
    do
    echo
    sleep 1
    echo -e "${Info}请选择ShadowsocksR的协议"
    echo
    for ((i=1;i<=${#protocols[@]};i++ )); do
        hint="${protocols[$i-1]}"
        echo -e "  ${Red_font}${i}${color_end}: ${hint}"
    done
    echo
    read -p "(回车默认: ${protocols[6]}):" protocol
    [ -z "$protocol" ] && protocol=7
    expr ${protocol} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e "${Error}请输入正确的数字！"
        echo
        continue
    fi
    if [[ "$protocol" -lt 1 || "$protocol" -gt ${#protocols[@]} ]]; then
        echo
        echo -e "${Error}数字范围: 1~${#protocols[@]}"
        echo
        continue
    fi
    shadowsockprotocol=${protocols[$protocol-1]}
    echo 
    echo -e "==================="
    echo
    echo -e "协议 = ${Red_font}${shadowsockprotocol}${color_end}"
    echo
    echo -e "==================="
    echo
    break
    done
}

error_detect_depends(){
    local command=$1
    local depend=`echo -e "${command}" | awk '{print $4}'`
    ${command}
    if [ $? != 0 ]; then
        echo -e "${Error}安装${Red_font}${depend}${color_end}失败！"
        exit 1
    fi
}

install_prepare_obfs() {
    while true
    do
    echo
    sleep 1
    echo -e "${Info}请选择ShadowsocksR的混淆方式"
    echo
    for ((i=1;i<=${#obfs[@]};i++ )); do
        hint="${obfs[$i-1]}"
        echo -e "  ${Red_font}${i}${color_end}: ${hint}"
    done
    echo
    read -p "(回车默认: ${obfs[1]}):" r_obfs
    echo
    [ -z "$r_obfs" ] && r_obfs=2
    expr ${r_obfs} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo
        echo -e "${Error}请输入正确的数字!"
        echo
        continue
    fi
    if [[ "$r_obfs" -lt 1 || "$r_obfs" -gt ${#obfs[@]} ]]; then
        echo
        echo -e "${Error}数字范围: 1~${#obfs[@]}"
        echo
        continue
    fi
    shadowsockobfs=${obfs[$r_obfs-1]}
    echo
    echo -e "==================="
    echo
    echo -e "混淆方式 = ${Red_font}${shadowsockobfs}${color_end}"
    echo
    echo -e "==================="
    echo
    break
    done
}

install_dependencies() {
    if check_sys packageManager yum; then
        echo -e "${Info}检查EPEL库..."
        if [ ! -f /etc/yum.repos.d/epel.repo ]; then
            yum install -y -q epel-release
        fi
        [ ! -f /etc/yum.repos.d/epel.repo ] && echo -e "${Error}安装EPEL库失败。" && exit 1
        [ ! "$(command -v yum-config-manager)" ] && yum install -y -q yum-utils
        if [ x"`yum-config-manager epel | grep -w enabled | awk '{print $3}'`" != x"True" ]; then
            yum-config-manager --enable epel
        fi
        echo -e "${Info}检查EPEL库完毕..."

        yum_depends=(
            unzip gzip openssl openssl-devel gcc python python-devel python-setuptools pcre pcre-devel libtool libevent xmlto
            autoconf automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel asciidoc
            libev-devel c-ares-devel git qrencode ntpdate
        )
        for depend in ${yum_depends[@]}; do
            error_detect_depends "yum -y install ${depend}"
        done
    elif check_sys packageManager apt; then
        apt_depends=(
            gettext build-essential unzip gzip python python-dev python-setuptools curl openssl libssl-dev
            autoconf automake libtool gcc make perl cpio libpcre3 libpcre3-dev zlib1g-dev libev-dev libc-ares-dev git qrencode ntpdate
        )

        apt-get -y update
        for depend in ${apt_depends[@]}; do
            error_detect_depends "apt-get -y install ${depend}"
        done
    fi
}

download() {
    local filename=$(basename $1)
    if [ -f ${1} ]; then
        echo -e "${filename} [已找到]"
    else
        echo -e "${filename} 未找到, 开始下载..."
        wget --no-check-certificate -c -t3 -T60 -O ${1} ${2}
        if [ $? -ne 0 ]; then
            echo -e "${Error}${filename} 下载失败！"
            exit 1
        fi
    fi
}

download_files() {
    cd ${cur_dir}
        download "${shadowsocks_r_file}.zip" "${shadowsocks_r_url}"
        if check_sys packageManager yum; then
            download "${shadowsocks_r_init}" "${shadowsocks_r_centos}"
        elif check_sys packageManager apt; then
            download "${shadowsocks_r_init}" "${shadowsocks_r_debian}"
        fi
}

config_shadowsocks() {

if check_kernel_version; then
    fast_open="true"
else
    fast_open="false"
fi

   if [ ! -d "$(dirname ${shadowsocks_r_config})" ]; then
        mkdir -p $(dirname ${shadowsocks_r_config})
    fi
    cat > ${shadowsocks_r_config}<<-EOF
{
    "server":"0.0.0.0",
    "server_ipv6":"::",
    "server_port":${shadowsocksport},
    "local_address":"127.0.0.1",
    "local_port":1080,
    "password":"${shadowsockspwd}",
    "timeout":120,
    "method":"${shadowsockscipher}",
    "protocol":"${shadowsockprotocol}",
    "protocol_param":"",
    "obfs":"${shadowsockobfs}",
    "obfs_param":"",
    "redirect":"",
    "dns_ipv6":false,
    "fast_open":${fast_open},
    "workers":1
}
EOF
}

check_kernel_version() {
    local kernel_version=$(uname -r | cut -d- -f1)
    if version_gt ${kernel_version} 3.7.0; then
        return 0
    else
        return 1
    fi
}

version_gt(){
    test "$(echo -e "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

config_firewall() {
    if centosversion 6; then
        /etc/init.d/iptables status > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
                iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
                /etc/init.d/iptables save
                /etc/init.d/iptables restart
            else
                echo -e "${Info}端口${Green_font}${shadowsocksport}${color_end} 已提前开放。"
            fi
        else
            echo -e "${Error}iptables没有安装或者未运行。"
        fi
    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/tcp
            firewall-cmd --permanent --zone=public --add-port=${shadowsocksport}/udp
            firewall-cmd --reload
        else
            echo -e "${Error}firewalld没有安装或者运行。"
        fi
    fi
}

get_ip() {
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

centosversion() {
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

getversion() {
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

install_main(){
    install_libsodium
    if ! ldconfig -p | grep -wq "/usr/lib"; then
        echo -e "/usr/lib" > /etc/ld.so.conf.d/lib.conf
    fi
    ldconfig
    install_shadowsocks_r
    install_completed_r
    #qr_generate_r
}

install_shadowsocks_r() {
    cd ${cur_dir}
    unzip -q ${shadowsocks_r_file}.zip
    if [ $? -ne 0 ];then
        echo -e "${Error}解压 ${shadowsocks_r_file}.zip 失败！"
        install_cleanup
        exit 1
    fi
    mv ${shadowsocks_r_file}/shadowsocks /usr/local/
    if [ -f /usr/local/shadowsocks/server.py ]; then
        chmod +x ${shadowsocks_r_init}
        local service_name=$(basename ${shadowsocks_r_init})
        if check_sys packageManager yum; then
            chkconfig --add ${service_name}
            chkconfig ${service_name} on
        elif check_sys packageManager apt; then
            update-rc.d -f ${service_name} defaults
        fi
    else
        echo
        echo -e "${Error}ShadowsocksR 安装失败！"
        install_cleanup
        exit 1
    fi
}

install_completed_r() {
    check_datetime
    ${shadowsocks_r_init} start
    cp ${shadowsocks_r_init} /bin/SSR
    chmod 777 /bin/SSR
    install_logo
    echo
    echo -e "${Green_font}ShadowsocksR${color_end}安装完成！"
    echo
    echo -e "服务器         ${Red_font} $(get_ip) ${color_end}"
    echo -e "远程端口        ${Red_font} ${shadowsocksport} ${color_end}"
    echo -e "密码           ${Red_font} ${shadowsockspwd} ${color_end}"
    echo -e "协议           ${Red_font} ${shadowsockprotocol} ${color_end}"
    echo -e "混淆方式        ${Red_font} ${shadowsockobfs} ${color_end}"
    echo -e "加密方法        ${Red_font} ${shadowsockscipher} ${color_end}"
    echo -e "\n===============================================\n   启动        停止       状态          重启      \n-----------------------------------------------\nSSR start | SSR stop | SSR status | SSR restart\n==============================================="
    echo
    echo -e "配置文件路径在${shadowsocks_r_config}"
    echo
    echo -e "想要修改加密方法、协议、端口密码等可浏览http://shiyu.pro/archives/ssr-obfs.html"
    echo
}

qr_generate_r() {
    if [ "$(command -v qrencode)" ]; then
        local tmp1=$(echo -n "${shadowsockspwd}" | base64 -w0 | sed 's/=//g;s/\//_/g;s/+/-/g')
        local tmp2=$(echo -n "$(get_ip):${shadowsocksport}:${shadowsockprotocol}:${shadowsockscipher}:${shadowsockobfs}:${tmp1}/?obfsparam=" | base64 -w0)
        local qr_code="ssr://${tmp2}"
        echo
        echo -e "Your QR Code: (For ShadowsocksR Windows, Android clients only)"
        echo -e "${Red_font} ${qr_code} ${color_end}"
        echo -n "${qr_code}" | qrencode -s8 -o ${cur_dir}/shadowsocks_r_qr.png
        echo -e "Your QR Code has been saved as a PNG file path:"
        echo -e "${Red_font} ${cur_dir}/shadowsocks_r_qr.png ${color_end}"
    fi
}

install_cleanup(){
    cd ${cur_dir}
    rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
    rm -rf ${shadowsocks_r_file} ${shadowsocks_r_file}.zip
}

libsodium_ver="1.0.16"
libsodium_file="libsodium-${libsodium_ver}"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/${libsodium_ver}/libsodium-${libsodium_ver}.tar.gz"
shadowsocks_r_file="shadowsocksr-manyuser"
shadowsocks_r_url="https://github.com/yi-shiyu/shadowsocksr/archive/manyuser.zip"
shadowsocks_r_init="/etc/init.d/shadowsocks-r"
shadowsocks_r_config="/etc/shadowsocks-r/config.json"
shadowsocks_r_centos="https://raw.githubusercontent.com/yi-shiyu/shadowsocks_install/master/shadowsocksR-debian"
shadowsocks_r_debian="https://raw.githubusercontent.com/yi-shiyu/shadowsocks_install/master/shadowsocksR-debian"
r_ciphers=(none aes-256-cfb aes-192-cfb aes-128-cfb aes-256-cfb8 aes-192-cfb8 aes-128-cfb8 aes-256-ctr aes-192-ctr aes-128-ctr chacha20-ietf chacha20 rc4-md5 rc4-md5-6)
protocols=(origin verify_deflate auth_sha1_v4 auth_sha1_v4_compatible auth_aes128_md5 auth_aes128_sha1 auth_chain_a auth_chain_b)
obfs=(plain http_simple http_simple_compatible http_post http_post_compatible tls1.2_ticket_auth tls1.2_ticket_auth_compatible tls1.2_ticket_fastauth tls1.2_ticket_fastauth_compatible)

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_shadowsocks
        ;;
    *)
        echo -e "Arguments error! [${action}]"
        echo -e "Usage: `basename $0` [install|uninstall]"
        ;;
esac
