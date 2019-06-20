#!/bin/bash
# chkconfig: 2345 90 10
# description: phpstrom License Server

do_start(){
    check_pid
    if [ ! -z "$PID" ]; then
        nohup /usr/local/IntelliJIDEA/LicenseServer -p 80 -u Shiyu >> /dev/null 2>&1 &
        echo "LicenseServer start!"
    else
        echo "LicenseServer is started!"
    fi
}

do_stop(){
    check_pid
    if [ ! -z "$PID" ]; then
        echo "LicenseServer not run!"
    else
        eval $(ps -ef | grep "LicenseServer -p" | awk '{print "kill "$2}')
        echo "LicenseServer stop!"
    fi
}

do_restart(){
    do_stop
    do_start
}

check_pid() {
    PID=`ps -ef | grep -v grep | grep -i "LicenseServer -p" | awk '{print $2}'`
}

do_status(){
    check_pid
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
