#!/bin/sh

out=/opt/starfish/tmp/sfgather.d
mkdir -p $out > /dev/null 2>&1 
cd $out
if [ $? -ne 0 ]; then
	echo chdir failed. Aborting
	exit 0
fi

PATH=/usr/bin:/usr/sbin:/bin:/sbin
export PATH

rm *

lscpu > lscpu 2>/dev/null
lshw --sanitize > lshw 2>/dev/null
cp /proc/meminfo meminfo
lsblk > lsblck 2>/dev/null
echo "------collecting 15 seconds of vmstat-----" 
vmstat -w 1 15 > vmstat
echo "------collecting 30s of disk stats-----" 
iostat -x -d 2 -N 10 > iostat
top -d 3 -n 3 > top
if [ -r /proc/slabinfo ]; then
	cp /proc/slabinfo slabinfo
fi
echo "------collecting sysctl-------" 
sysctl -a > sysctl 2>&1
ip addr > interfaces
#usefulints=`ip link | gawk ' $1 ~ /[0-9]:/ && $2 !~ /lo:|@|\./ {d[++i]=sprintf ("%.*s", length($2)-1, $2);} END {for (n=1; n<i; n++) {printf("%s,",d[n]); print d[++n] ",total"}}'`
if [ -x /usr/bin/dstat ]; then
	echo "------collecting dstat for 8 sec-------" 
	dstat -n 1 8 > dstat.out
fi

if [ -x /usr/sbin/iotop ]; then
	echo "------collecting iotop for 10 seconds---" 
	iotop -n 10 -d 1 > iotop 2>/dev/null
fi


cd ..
tar cfz sfgather.tar.gz sfgather.d
