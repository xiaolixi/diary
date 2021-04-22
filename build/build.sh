#!/bin/bash

## 加载环境变量
function loadEnv() {
    set +x;
    source /etc/profile;
    set -x
}
# 日志打印函数
function logger() {
	local date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$1:${date} $2"
}

## 设置变量
function setVariables(){
    # 当前项目的路径
    currentProjectName="/path/to/project"
    # 后端项目名称
    backendProjectName="123"
    # 后端项目git路径
    backendProjectGitUrl="http://asfasf/sdfsf.git"
    # 前端文件在后端项目的相对路径
    staticFileRelativePath="src/main/resources/static/"
    # jar相对后端项目的路径
    jarFileRelativePath="target/*.jar"
    # docker镜像名称
    imageName="${backendProjectName}"
    # docker镜像版本
    imageTag=1.0.0
    # nodePort
    nodePort=38080
    # 后端项目的临时目录
    tempBackendProjectPath="/tmp/cicd/${backendProjectName}"
    # 构建的分支或者tag名
    buildBranhOrTag="${gitlabBranch##*/}"
    # 文件服务器的IP
    fileServerIP="192.168.11.200"
    # 文件服务器的路径
    fileServierPath="/var/www/html/"
    if [[ ${buildBranhOrTag} =~ (-rls|-pkg|-tst) ]];then
        imageTag="${buildBranhOrTag:0-7:3}"
        imageTag="${imageTag:0:1}.${imageTag:1:1}.${imageTag:2:1}"
    fi
}

function clean(){
    logger "INFO" "clean env"

}

function deployToTestEnv(){
    logger "INFO" "deploy to test env"
    local imageRepo="test.harbor.com"
    docker tag ${imageName}:${imageTag} ${imageRepo}/${imageName}:${imageTag}

    chmod +x "${tempBackendProjectPath}/deploy/test/build.sh"
    ${tempBackendProjectPath}/deploy/test/build.sh  "${imageName}" "${nodePort}" "${imageRepo}/${imageName}" "${imageTag}"
}

function deployToProd(){
    echo "asd"
}

# 上传到文件服务器上
function upload(){
    # 创建目录
    ssh root@"${fileServerIP}" "mkdir -p ${fileServierPath}/${backendProjectName}"
    # 上传
    scp "${tempBackendProjectPath}/deploy/online/*" "${fileServierPath}/${backendProjectName}"
}

# 合并前后端项目
function merge(){
    # clone后端项目
    if [[ -d "${tempBackendProjectPath}" ]];then
        mkdir -p "${tempBackendProjectPath}"
        git clone "${backendProjectGitUrl}"
    fi
    # 后端项目绝对路径
    local realProjectName=$(ls "${tempBackendProjectPath}")
    tempBackendProjectPath="${tempBackendProjectPath}/${realProjectName}"

    # 先删除后端项目中的前端文件
    rm -rf "${tempBackendProjectPath}/${staticFileRelativePath}/*"
    # 再拷贝
    cp -rf "${currentProjectName}/dist/*" "${tempBackendProjectPath}/${staticFileRelativePath}"

    # 编译后端项目
    mvn clean package -Dmaven.test.skip=true

    # 拷贝到后端目录中去
    cp -f "${tempBackendProjectPath}/${jarFileRelativePath}" "${tempBackendProjectPath}/deploy/jar/${backendProjectName}.jar"

    docker rmi -f $(docker images ${imageName} | grep -v TAG | awk '{print $3}' | sort | uniq)
    # 构建镜像
    docker build -t "${imageName}:${imageTag}" --build-arg APP="${imageName}" "${tempBackendProjectPath}/deploy/jar/"

    if [[ ${buildBranhOrTag} =~ -tst ]];then
        deployToTestEnv
    elif [[ ${buildBranhOrTag} =~ (-rls|-pkg) ]];then
        deployToProd
    fi
}
function build(){
    # 前端构建
    [[ -d node_modeles ]] || npm install --unsafe-perm=true --allow-root
    [[ -d dist ]] && rm -rf dist
    npm run build

    # 非tag直接返回
    if [[ ! ${buildBranhOrTag} =~ (-rls|-pkg|-tst) ]];then
        return
    fi

    merge
}

function main(){
    loadEnv
    setVariables
    build
}

main

# declare -r
# declare -p
# declare -i
# declare -x
# declare -a



## 最后，我们对以上 8 种格式做一个汇总，请看下表：
## 格式	说明
## ${string: start :length}	从 string 字符串的左边第 start 个字符开始，向右截取 length 个字符。
## ${string: start}	从 string 字符串的左边第 start 个字符开始截取，直到最后。
## ${string: 0-start :length}	从 string 字符串的右边第 start 个字符开始，向右截取 length 个字符。
## ${string: 0-start}	从 string 字符串的右边第 start 个字符开始截取，直到最后。
## ${string#*chars}	从 string 字符串第一次出现 *chars 的位置开始，截取 *chars 右边的所有字符。
## ${string##*chars}	从 string 字符串最后一次出现 *chars 的位置开始，截取 *chars 右边的所有字符。
## ${string%*chars}	从 string 字符串第一次出现 *chars 的位置开始，截取 *chars 左边的所有字符。
## ${string%%*chars}	从 string 字符串最后一次出现 *chars 的位置开始，截取 *chars 左边的所有字符。



