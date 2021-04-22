#!/bin/bash

nodejsUrl="https://nodejs.org/dist/v14.16.1/node-v14.16.1-linux-x64.tar.xz"
nodejsPackage="node-v14.16.1-linux-x64.tar.xz"
# 日志打印函数
function logger() {
	local date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$1:${date} $2"
}

function download() {
    wget ${nodejsUrl}
    mv ${nodejsPackage} /opt
}

function install() {
    cd /opt
    nodeName=$(tar -xf ${nodejsPackage} | awk 'NR==1')
    ln  -s   /opt/${nodeName}  /opt/nodejs
    ln -sf /opt/nodejs/bin/node /usr/local/bin/node
    ln -sf /opt/nodejs/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm
    ln -sf /opt/nodejs/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx
}


function vertify() {
    npm -v
    node -v
}


function main() {
    download
    install
    vertify
}

main
