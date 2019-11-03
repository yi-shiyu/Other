#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
echo "请在导入数据库数据后执行此脚本。"
echo "输入网站网址："
read http
echo "输入网站目录的绝对路径。"
read path
cd ${path}
git clone -b master https://github.com/yi-shiyu/SSPanel-Uim.git tmp && mv tmp/.git . && rm -rf tmp && git reset --hard
git config core.filemode false
wget https://getcomposer.org/installer -O composer.phar
php composer.phar
php composer.phar install
cp config/.config.example.php config/.config.php
cd ../
chmod -R 755 ${path}
chown www:www -R ${path}
echo "随便输入几个数字来加密："
read salt
echo "数据库地址："
read host
echo "数据库名："
read datebase
echo "数据库用户名："
read dateuser
echo "数据库密码："
read pass
cd ${path}

config_file=${path}/config/.config.php

sed -i "18s|1145141919810|${salt}|" ${config_file}
sed -i "21s|http://url.com|${http}|" ${config_file}
sed -i "25s|localhost|${host}|" ${config_file}
sed -i "26s|sspanel|${datebase}|" ${config_file}
sed -i "27s|root|${dateuser}|" ${config_file}
sed -i "28s|sspanel|${pass}|" ${config_file}

php xcat createAdmin
php xcat syncusers
php xcat initQQWry
php xcat resetTraffic
php xcat initdownload

cat >> /var/spool/cron/root << EOF
30 22 * * * php ${path}/xcat sendDiaryMail
0 0 * * * php -n ${path}/xcat dailyjob
*/1 * * * * php ${path}/xcat checkjob
*/1 * * * * php ${path}/xcat syncnode
EOF

cat << EOF
location / {
    try_files $uri /index.php$is_args$args;
}
EOF
