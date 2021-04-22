#!/bin/bash


# 日志打印函数
function logger() {
	local date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$1:${date} $2"
}

function download() {
    yum install --downloadonly --downloaddir=./ expect
}

function install() {
    rpm -ivh tcl-8.5.13-8.el7.x86_64.rpm
    rpm -ivh expect-5.45-14.el7_1.x86_64.rpm
}

function main() {
    download
    install
}

main
