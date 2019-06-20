#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

License_path="/usr/local/IntelliJIDEA"
License_url="https://raw.githubusercontent.com/yi-shiyu/Other/master/LicenseServer"
License_init="/etc/init.d/LicenseServer"
License_init_url="https://github.com/yi-shiyu/Other/raw/master/license.sh"
License_file="LicenseServer"


uninstall_license() {
    service ${License_file} stop
    chkconfig ${License_file} off
    chkconfig --del ${License_file}
    rm -rf ${License_path}
    rm -f ${License_init}
    echo "Uninstall success!"
}

download() {
    wget --no-check-certificate -c -t3 -T60 -O ${1} ${2}
    if [ $? -ne 0 ]; then
         echo -e "${Error}${filename} 下载失败！"
         exit 1
    fi
}

download_files() {
    mkdir ${License_path}
    download "${License_path}/${License_file}" "${License_url}"
    download "${License_init}" "${License_init_url}"
}

config_license() {
    sed -i 's/-p 80 -u Shiyu/-p '${port_number}' -u '${license_name}'/g' ${License_init}
    cd ${License_path}
    chmod +x ${License_file}
    chmod +x ${License_init}
    chkconfig --add ${License_file}
    chkconfig ${License_file} on
    service ${License_file} start
}

custome_license() {
    sleep 1
    echo
    echo -e "请输入要使用的端口号:"
    echo
    read -p "(回车默认: 80):" port_number
    [ -z "${port_number}" ] && port_number=80
    echo
    echo -e "端口: ${port_number}"
    echo
    sleep 1
    echo
    echo -e "请输入自定义的证书用户名:"
    echo
    read -p "(回车默认: Shiyu):" license_name
    [ -z "${license_name}" ] && license_name="Shiyu"
    echo
    echo -e "证书名: ${license_name}"
    echo
}

install_license() {
    download_files
    custome_license
    config_license
}

action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_license
        ;;
    *)
        echo -e "Arguments error! [${action}]"
        echo -e "Usage: `basename $0` [install|uninstall]"
        ;;
esac
