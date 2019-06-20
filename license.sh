#!/bin/bash
# chkconfig: 2345 90 10
# description: phpstrom License Server

do_start(){
    PID=`ps -ef | grep -v grep | grep -i "[0-9] LicenseServer" | awk '{print $2}'`
    if [ ! -z "$PID" ]; then
        cd /usr/local/IntelliJIDEA
        nohup LicenseServer -p 80 -u Shiyu >> /dev/null 2>&1 &
        echo "LicenseServer start!"
    else
        echo "LicenseServer is started!"
    fi
}

do_stop(){
    PID=`ps -ef | grep -v grep | grep -i "[0-9] LicenseServer" | awk '{print $2}'`
    if [ ! -z "$PID" ]; then
        echo "LicenseServer not run!"
    else
        cd /usr/local/IntelliJIDEA
        eval $(ps -ef | grep "[0-9] LicenseServer" | awk '{print "kill "$2}')
        echo "LicenseServer stop!"
    fi
}

do_restart(){
    do_stop
    do_start
}

do_status(){
    PID=`ps -ef | grep -v grep | grep -i "[0-9] LicenseServer" | awk '{print $2}'`
    if [ ! -z "$PID" ]; then
        echo "LicenseServer is running!"
    else
        echo "LicenseServer is stopped"
    fi
}

case "$1" in
  start|stop|restart|status)
    do_$1
    ;;
    *)
    echo "Usage: $0 { start | stop | restart | status }"
    exit 1
    ;;
esac
