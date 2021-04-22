#!/bin/bash

function remove_marisa(){
  rpm -e --nodeps $(rpm -qa |grep marisa)
}

function install(){
  rpm -ivh mysql-community-common-5.7.26-1.el7.x86_64.rpm
  rpm -ivh mysql-community-libs-5.7.26-1.el7.x86_64.rpm
  rpm -ivh mysql-community-client-5.7.26-1.el7.x86_64.rpm
}

function main(){
  remove_marisa
  install
}

main
