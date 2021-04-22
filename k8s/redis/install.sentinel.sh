#!/bin/bash
set -x
IP=192.168.1.20
image="redis:5.0"

path=$(cd $(dirname $0) && pwd)
master_port=16379

for ((i=0;i<3;i++)) 
do
	cport=$[ $master_port + $i ]
	mkdir -p ${path}/redis_${cport}/data -pv
	cp ${path}/redis.conf   ${path}/redis_${cport}/redis.conf
	sed -i "s|6379|${cport}|"  ${path}/redis_${cport}/redis.conf
	if [[ ${cport} == $master_port ]];then
		sed -i "s|^slaveof.*$||"  ${path}/redis_${cport}/redis.conf
	else
		sed -i "s|^slaveof.*$|slaveof ${IP} ${master_port}|"  ${path}/redis_${cport}/redis.conf
	fi
	docker run --net=host -p ${cport}:${cport} --name master_${cport} \
-v ${path}/redis_${cport}/redis.conf:/etc/redis/redis.conf \
-v ${path}/redis_${cport}/data/:/data \
-d ${image} redis-server /etc/redis/redis.conf
done

##sentinel.conf
sentinel_port=26379

for ((i=0;i<3;++i))
do
	sport=$[ $sentinel_port + $i ]
	mkdir  ${path}/sentinel_${sport}/data -pv

	cp ${path}/sentinel.conf  ${path}/sentinel_${sport}/sentinel.conf
	chmod -R 777  sentinel_${sport} 
	sed -i "s|sentinel_port|${sport}|"  ${path}/sentinel_${sport}/sentinel.conf
	sed -i "s|IP|${IP}|"  ${path}/sentinel_${sport}/sentinel.conf
	sed -i "s|master_port|${master_port}|"  ${path}/sentinel_${sport}/sentinel.conf
	docker run --net=host --privileged=true -p ${sport}:${sport} --name sentinel_${sport} \
-v ${path}/sentinel_${sport}/sentinel.conf:/etc/redis/sentinel.conf \
-v ${path}/sentinel_${sport}/data/:/data \
-d ${image}  redis-server /etc/redis/sentinel.conf --sentinel
done

docker ps -a | grep redis

