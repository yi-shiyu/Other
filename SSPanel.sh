#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

Green_font="\033[32m"
Red_font="\033[31m"
Red_background="\033[41;37m"
color_end="\033[0m"

Error="${Red_font}错误${color_end}: "
Info="${Green_font}提示${color_end}: "

cur_dir=`pwd`

install_logo() {
    clear
    echo -e "\n==================================\n\n\t${Green_font}ShadowsocksR SSPanel 后端一键脚本${color_end}.\n\nAuthor:${Red_background}Shiyu${color_end}\n\n=================================="
}

uninstall_shadowsocksr() {
  if [ -f ${shadowsocksr_init} ]; then
    echo -e "${Info}你确定卸载${Red_font}ShadowsocksR${color_end}? [y/n]\n"
    read -p "(default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
      ${shadowsocksr_init} status > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo
        ${shadowsocksr_init} stop
      fi
      local service_name=$(basename ${shadowsocksr_init})
      chkconfig --del ${service_name}
      rm -f ${shadowsocksr_init}
      rm -rf /usr/local/${shadowsocksr_file}
      rm -f /bin/shadowsocksr
      echo
      echo -e "${Info}ShadowsocksR卸载完成！"
      echo
    else
      echo
      echo -e "${Info}ShadowsocksR卸载取消…"
      echo
    fi
  else
    echo
    echo -e "${Error}ShadowsocksR未用此脚本安装，无法卸载！"
    echo
    exit 1
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
    download "${shadowsocksr_file}.zip" "${shadowsocksr_url}"
    download "${shadowsocksr_init}" "${shadowsocksr_chkconfig}"
    download "${libsodium_file}.tar.gz" "${libsodium_url}"
}

install_main(){
  install_logo
  install_prepare
  disable_selinux
  config_firewall
  install_dependencies
  download_files
  install_completed
  install_libsodium
  install_cleanup
}

install_libsodium() {
    if [ ! -f /usr/lib/libsodium.a ]; then
        cd ${cur_dir}
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

install_shadowsocksr() {
  install_main
  if [ -f /usr/local/shadowsocksr/server.py ]; then
    chmod +x ${shadowsocksr_init}
    local service_name=$(basename ${shadowsocksr_init})
    chkconfig --add ${service_name}
    chkconfig ${service_name} on
    echo -e "${Info}ShadowsocksR 安装成功！"
    
  else
    echo
    echo -e "${Error}ShadowsocksR 安装失败！"
    exit 1
  fi
  ln -s ${shadowsocksr_init} /bin/shadowsocksr
  chmod +x /bin/shadowsocksr
}

check_kernel_version(){
  local kernel_version=$(uname -r | cut -d- -f1)
  if version_gt ${kernel_version} 3.7.0; then
    return 0
  else
    return 1
  fi
}

version_gt() {
  test "$(echo -e "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

install_completed() {
  cd ${cur_dir}
  unzip -q ${shadowsocksr_file}.zip
  if [ $? -ne 0 ];then
    echo -e "${Error}解压 ${shadowsocks_r_file}.zip 失败！"
    exit 1
  fi
  if check_kernel_version; then
    fast_open="true"
  else
    fast_open="false"
  fi
  mv ${shadowsocksr_file} /usr/local
  cd /usr/local/${shadowsocksr_file}
  rm -rf CyMySQL
  rm -rf cymysql
  git clone https://github.com/nakagami/CyMySQL.git
  mv CyMySQL/cymysql ./
  rm -rf CyMySQL
  chmod +x *.sh
  chmod +x shadowsocks/*.sh
  sed -i 's/UPDATE_TIME = 30/UPDATE_TIME = '${shadowsocksruptime}'/g' apiconfig.py
  sed -i 's/"method": "none"/"method": "'${shadowsocksrmethod}'"/g' config.json
  sed -i 's/"protocol": "auth_chain_a"/"protocol": "'${shadowsocksrprotocol}'"/g' config.json
  sed -i 's/"protocol_param": "2"/"protocol_param": "'${shadowsocksrprotocolparam}'"/g' config.json
  sed -i 's/"speed_limit_per_user": 5000/"speed_limit_per_user": '${shadowsocksrperuser}'/g' config.json
  sed -i 's/"obfs": "http_simple_compatible"/"obfs": "'${shadowsocksrobfs}'"/g' config.json
  sed -i 's/"fast_open": false/"fast_open": '${fast_open}'/g' config.json
  sed -i 's/"host": "127.0.0.1"/"host": "'${shadowsocksrhost}'"/g' mysql.json
  sed -i 's/"user": "ss"/"user": "'${shadowsocksruser}'"/g' mysql.json
  sed -i 's/"password": "pass"/"password": "'${shadowsocksrpasswd}'"/g' mysql.json
  sed -i 's/"db": "sspanel"/"db": "'${shadowsocksruserdb}'"/g' mysql.json
  cp -n apiconfig.py userapiconfig.py
  cp -n config.json user-config.json
  cp -n mysql.json usermysql.json
}

install_prepare() {
  install_shadowsocksr_method
  install_shadowsocksr_protocol
  install_shadowsocksr_protocol_param
  install_shadowsocksr_obfs
  install_shadowsocksr_per_user
  install_shadowsocksr_uptime
  install_shadowsocksr_host
  install_shadowsocksr_user
  install_shadowsocksr_passwd
  install_shadowsocksr_db
  echo -e "${Info}按任意键开始搭建...或者按 Ctrl+C 取消。"
  char=`get_char`
}

install_shadowsocksr_db() {
  sleep 1
  echo
  echo -e "${Info}请输入ShadowsocksR的数据库名"
  echo
  read -p "(回车默认: user_db):" dbuser_db
  [ -z "${dbuser_db}" ] && dbuser_db="user_db"
  shadowsocksruserdb=${dbuser_db}
  echo
  echo -e "用户: ${Red_font}${shadowsocksruserdb}${color_end}"
  echo
}

install_shadowsocksr_passwd() {
  sleep 1
  echo
  echo -e "${Info}请输入ShadowsocksR的数据库用户密码"
  echo
  read -p "(回车默认: 123456):" dbpass
  [ -z "${dbpass}" ] && dbpass="123456"
  shadowsocksrpasswd=${dbpass}
  echo
  echo -e "密码: ${Red_font}${shadowsocksrpasswd}${color_end}"
  echo
}

install_shadowsocksr_user() {
  sleep 1
  echo
  echo -e "${Info}请输入ShadowsocksR的数据库用户"
  echo
  read -p "(回车默认: user):" dbuser
  [ -z "${dbuser}" ] && dbuser="user"
  shadowsocksruser=${dbuser}
  echo
  echo -e "用户: ${Red_font}${shadowsocksruser}${color_end}"
  echo
}

install_shadowsocksr_host() {
  sleep 1
  echo
  echo -e "${Info}请输入ShadowsocksR的数据库地址"
  echo
  read -p "(回车默认: 127.0.0.1):" host
  [ -z "${host}" ] && host="127.0.0.1"
  shadowsocksrhost=${host}
  echo
  echo -e "地址: ${Red_font}${shadowsocksrhost}${color_end}"
  echo
}

install_shadowsocksr_uptime() {
  sleep 1
  echo
  echo -e "${Info}请输入ShadowsocksR的数据库更新频率/S"
  echo
  read -p "(回车默认: 60):" uptime
  [ -z "${uptime}" ] && uptime=60
  shadowsocksruptime=${uptime}
  echo
  echo -e "频率: ${Red_font}${shadowsocksruptime}${color_end}"
  echo
}

install_shadowsocksr_per_user() {
  echo
  sleep 1
  echo -e "${Info}请输入ShadowsocksR的限速KB/s"
  echo
  read -p "(回车默认: 0):" peruser
  [ -z "${peruser}" ] && peruser=0
  shadowsocksrperuser=${peruser}
  echo
  echo -e "限速: ${Red_font}${shadowsocksrperuser}${color_end}"
  echo
}

install_shadowsocksr_obfs() {
  while true
  do
  echo
  sleep 1
  echo -e "${Info}请选择ShadowsocksR的混淆方式"
  echo
  for ((i=1;i<=${#shadowsocksr_obfs[@]};i++ )); do
    hint="${shadowsocksr_obfs[$i-1]}"
    echo -e "  ${Red_font}${i}${color_end}: ${hint}"
  done
  echo
  read -p "(回车默认: ${shadowsocksr_obfs[2]}):" pickobf
  [ -z "$pickobf" ] && pickobf=3
  expr ${pickobf} + 1 &>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "${Error}请输入正确的数字!"
    continue
  fi
  if [[ "$pickobf" -lt 1 || "$pickobf" -gt ${#shadowsocksr_obfs[@]} ]]; then
    echo -e "${Error}数字范围: 1~${#shadowsocksr_obfs[@]}"
    continue
  fi
  shadowsocksrobfs=${shadowsocksr_obfs[$pickobf-1]}
  echo
  echo -e "混淆方式 = ${Red_font}${shadowsocksrobfs}${color_end}"
  echo
  break
  done
}

install_shadowsocksr_protocol_param() {
  echo
  sleep 1
  echo -e "${Info}请输入ShadowsocksR的协议参数"
  echo
  read -p "(回车默认: 2):" protocolparam
  [ -z "${protocolparam}" ] && protocolparam=2
  shadowsocksrprotocolparam=${protocolparam}
  echo
  echo -e "协议参数: ${Red_font}${shadowsocksrprotocolparam}${color_end}"
  echo
}

install_shadowsocksr_protocol() {
  while true
  do
  echo
  sleep 1
  echo -e "${Info}请选择ShadowsocksR的协议"
  echo
  for ((i=1;i<=${#shadowsocksr_protocol[@]};i++ )); do
    hint="${shadowsocksr_protocol[$i-1]}"
    echo -e "  ${Red_font}${i}${color_end}: ${hint}"
  done
  echo
  read -p "(回车默认: ${shadowsocksr_protocol[6]}):" pickprotocol
  [ -z "$pickprotocol" ] && pickprotocol=7
  expr ${pickprotocol} + 1 &>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "${Error}请输入正确的数字!"
    continue
  fi
  if [[ "$pickprotocol" -lt 1 || "$pickprotocol" -gt ${#shadowsocksr_protocol[@]} ]]; then
    echo -e "${Error}数字范围: 1~${#shadowsocksr_protocol[@]}"
    continue
  fi
  shadowsocksrprotocol=${shadowsocksr_protocol[$pickprotocol-1]}
  echo
  echo -e "协议 = ${Red_font}${shadowsocksrprotocol}${color_end}"
  echo
  break
  done
}

install_shadowsocksr_method() {
  while true
  do
  echo
  sleep 1
  echo -e "${Info}请选择ShadowsocksR的加密方法"
  echo
  for ((i=1;i<=${#shadowsocksr_method[@]};i++ )); do
    hint="${shadowsocksr_method[$i-1]}"
    echo -e "  ${Red_font}${i}${color_end}: ${hint}"
  done
  echo
  read -p "(回车默认: ${shadowsocksr_method[0]}):" pick
  [ -z "$pick" ] && pick=1
  expr ${pick} + 1 &>/dev/null
  if [ $? -ne 0 ]; then
    echo -e "${Error}请输入正确的数字!"
    continue
  fi
  if [[ "$pick" -lt 1 || "$pick" -gt ${#shadowsocksr_method[@]} ]]; then
    echo -e "${Error}数字范围: 1~${#shadowsocksr_method[@]}"
    continue
  fi
  shadowsocksrmethod=${shadowsocksr_method[$pick-1]}
  echo
  echo -e "加密方法 = ${Red_font}${shadowsocksrmethod}${color_end}"
  echo
  break
  done
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

config_firewall() {
  systemctl stop firewalld
  systemctl disable firewalld
  firewall-cmd --state
  rm -rf /etc/localtime
  ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  echo "DNS1=8.8.8.8" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  echo "DNS2=8.8.4.4" >> /etc/sysconfig/network-scripts/ifcfg-eth0
  rm -f /etc/resolv.conf
  service network restart
}

disable_selinux() {
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
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

install_dependencies() {
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
  for depend in ${yum_depends[@]}; do
    error_detect_depends "yum -y install ${depend}"
  done
}

install_cleanup() {
  cd ${cur_dir}
  rm -rf ${shadowsocksr_file} ${shadowsocksr_file}.zip
  rm -rf ${libsodium_file} ${libsodium_file}.tar.gz
}


libsodium_ver="1.0.16"
libsodium_file="libsodium-${libsodium_ver}"
libsodium_url="https://github.com/jedisct1/libsodium/releases/download/${libsodium_ver}/libsodium-${libsodium_ver}.tar.gz"
shadowsocksr_method=(none aes-256-cfb aes-192-cfb aes-128-cfb aes-256-cfb8 aes-192-cfb8 aes-128-cfb8 aes-256-ctr aes-192-ctr aes-128-ctr chacha20-ietf chacha20 rc4-md5 rc4-md5-6)
shadowsocksr_protocol=(origin verify_deflate auth_sha1_v4 auth_sha1_v4_compatible auth_aes128_md5 auth_aes128_sha1 auth_chain_a auth_chain_b)
shadowsocksr_obfs=(plain http_simple http_simple_compatible http_post http_post_compatible tls1.2_ticket_auth tls1.2_ticket_auth_compatible tls1.2_ticket_fastauth tls1.2_ticket_fastauth_compatible)
yum_depends=(unzip gzip openssl openssl-devel gcc python python-devel python-setuptools pcre pcre-devel libtool libevent xmlto autoconf automake make curl curl-devel zlib-devel perl perl-devel cpio expat-devel gettext-devel asciidoc libev-devel c-ares-devel git qrencode ntpdate)
shadowsocksr_file="shadowsocksr"
shadowsocksr_chkconfig="https://raw.githubusercontent.com/yi-shiyu/Other/master/shadowsocksr"
shadowsocksr_url="https://github.com/yi-shiyu/Other/releases/download/ssr/shadowsocksr.zip"
shadowsocksr_init="/etc/init.d/shadowsocksr"

action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_shadowsocksr
        ;;
    *)
        echo -e "Arguments error! [${action}]"
        echo -e "Usage: `basename $0` [install|uninstall]"
        ;;
esac
