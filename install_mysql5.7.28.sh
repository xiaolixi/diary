#!/bin/bash

function remove_marisa(){
  rpm -e --nodeps $(rpm -qa |grep marisa)
}

function install(){
  rpm -ivh mysql-community-common-5.7.26-1.el7.x86_64.rpm
  rpm -ivh mysql-community-libs-5.7.26-1.el7.x86_64.rpm
  rpm -ivh mysql-community-client-5.7.26-1.el7.x86_64.rpm
  rpm -ivh mysql-community-server-5.7.26-1.el7.x86_64.rpm
  mysql -V
  
  systemctl start mysqld
  systemctl enable mysqld
  systemctl status mysqld
  
  cat /var/log/mysqld.log |grep password
  
  mysql -uroot -p
  
}
