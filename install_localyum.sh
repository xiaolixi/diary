#!/bin/bash

objectPAth="/repo"
# 日志打印函数
function logger() {
	local date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$1:${date} $2"
}

function prapre() {
    mkdir "${objectPAth}"
    mount /dev/sr0 "${objectPAth}"
    df -h
}

function install() {
    systemctl disable firewalld
    systemctl stop firewalld
    # 安装httpd和createrepo
    yum -y install httpd createrepo
    # 配置yum
    echo "Alias ${objectPAth} \"/var/www/html/yum\"" > /etc/httpd/conf.d/yum.conf
    # 制作库
    mkdir -p /var/www/html/yum
    cp ${objectPAth}/Packages/* /var/www/html/yum
    # 生成库
    createrepo /var/www/html/yum
    cat > /etc/yum.repos.d/local.repo << EOF
[local]
name=local
baseurl=file:///var/www/html/yum
gpgcheck=0
enabled=1
EOF
    # 修改服务器的文件
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/CentOS-* /etc/yum.repos.d/backup

    systemctl start httpd
    systemctl status httpd
    systemctl enable httpd
    yum clean all
    yum repolist
}




function clinet() {
    # 修改服务器的文件
    mkdir -p /etc/yum.repos.d/backup
    mv /etc/yum.repos.d/CentOS-* /etc/yum.repos.d/backup
    cat > /etc/yum.repos.d/local.repo << EOF
[local]
name=local
baseurl=file:///var/www/html/yum
gpgcheck=0
enabled=1
EOF

    yum clean all
    yum repolist
}

function main() {
    prapre
    install
}

main
