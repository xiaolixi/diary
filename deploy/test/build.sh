#!/bin/bash

dir=$(cd $(dirname $0) && pwd)

export SERVICE_NAME="$1"
export SERVICE_PORT="$2"
export IMAGE_NAME="$3"
export IMAGE_TAG="$4"

# 日志打印函数
function logger() {
	local date=$(date +"%Y-%m-%d %H:%M:%S")
	echo "$1:${date} $2"
}

function envsubst_dir(){
    for file in $(ls $1); do
        if [[ -d "$1/$file" ]]; then
            mkdir -p $2/$file
            envsubst_dir "$1/$file" "$2/$file"
        elif [[ $file == *-tpl.* ]]; then
            echo "subst: $1/$file > $2/${file/-tpl/}"
            envsubst < "$1/$file" > "$2/${file/-tpl/}"
        else
            echo "copy : $1/$file > $2/$file"
            cp "$1/$file" "$2/$file"
        fi
    done
}

function main() {
    mkdir -p "${dir}/result"
    envsubst_dir "${dir}/template" "${dir}/result"

    for file in $(ls ${dir}/result); do
        kubectl apply -f "${dir}/result/${file}"
    done
}

main







