#! /bin/bash
## 使用方法
## git checkout 到想要统计的分支
## 将该脚本复制到与.git用一级目录
## 运行该脚本自动输出每个人的代码量
set -o
set +e
#set -x
CURRENTPATH=`pwd`
STARTTIME="2010-04-01"
STARTTIMESTAMP=`date -d "${STARTTIME}" +%s`
declare -A name2CountArray
#git reset --hard HEAD

function cleanSourceCode(){
# 删除空白行
# 删除以//开头的单行注释
# 删除以#开头的单行注释
# 删除以import开头的行
# 删除/* 开头和以*/结束的多行注释
 local sourceCcodeFile="$1"
 #                      import                     #                                                 //                    /*.....*/                   空行     
 sed -i -E -e '/^[^)]*\)[[:blank:]]*import.*$/d; /^[^)]*\)[[:blank:]]*#.*$/d; /^[^)]*\)[[:blank:]]*\/\/.*$/d; /^[^)]*\)[[:blank:]]*\/\*/,/.*\*\//d; /^[^)]*\)[[:blank:]]*$/d' ${sourceCcodeFile}
}

################
# 判断是否是源代码目录
#target、static、logs、build、node_modules、dist 
################
function isSourceCodeDir(){
 local dir="$1"
 if [[ ${dir} != target ]];then
  return 1
 elif [[ ${dir} !=  tatic ]];then
  return 1
 elif [[ ${dir} != logs ]];then
  return 1
 elif [[ ${dir} != build ]];then
  return 1
 elif [[ ${dir} != node_modules ]];then
  return 1
 elif [[ ${dir} != dist ]];then
  return 1
 else
  return 0
 fi
}

################
# 判断是否是源代码文件
# =~：正则匹配，用来判断其左侧的参数是否符合右边的要求
################
function isSourceCodeFile(){
 local file="$1"
 if [[ ${file} =~ .java ]];then
  return 1
 elif [[ ${file} =~ .vue ]];then
  return 1
 elif [[ ${file} =~ .css ]];then
  return 1
 elif [[ ${file} =~ .js ]];then
  return 1
 elif [[ ${file} =~ .html ]];then
  return 1
 elif [[ ${file} =~ .xml ]];then
  return 1
 elif [[ ${file} =~ .yaml ]];then
  return 1
 elif [[ ${file} =~ .yml ]];then
  return 1
 elif [[ ${file} =~ .json ]];then
  return 1
 elif [[ ${file} =~ .properties ]];then
  return 1
 elif [[ ${file} =~ .md ]];then
  return 1
 else
  return 0
 fi
}

function read_dir(){
 #$1为路径参数，ls出当前目录下的文件
 local fileDir="$1"
 local fileList=`ls $1`
 for file in ${fileList} #遍历所有的文件、目录 
 do
   if [[ -d ${fileDir}/${file} ]];then
	isSourceCodeDir ${file}
	if [[ $? -eq 1 ]];then
     #递归调用
     read_dir ${fileDir}/${file}  
     fi
   else
   isSourceCodeFile ${file}
   if [[ $? -eq 1 ]];then
    cleanSourceCode ${fileDir}/${file}
    # git blame在给定文件中的每一行中注释来自最后修改该行的修订者信息。可以选择从给定修订版本开始注释。
       # commit-ID 文件路径 (代码提交作者  提交时间  代码位于文件中的行数)  实际代码
       # 46fcdcb53 (****** 2019-11-21 11:49:05 +0800 38)       - name: data
        
     git blame -t --root ${fileDir}/${file} \
     | sed  -E -e 's/^[^(]*\(//g' \
     | awk 'BEGIN{startTimeStamp="'"$STARTTIMESTAMP"'"}{ endTimeStamp = $2; if (endTimeStamp>startTimeStamp){print $0}}' \
     | cut -d ' ' -f 1 \
     | sort \
     | uniq -c > ${CURRENTPATH}/res.txt
          
     while read line
     do
       nameCountArray=(${line})
       name2CountArray[${nameCountArray[1]}]=$((name2CountArray[${nameCountArray[1]}]+${nameCountArray[0]}))
       done < ${CURRENTPATH}/res.txt
       cat /dev/null > ${CURRENTPATH}/res.txt
    fi   
   fi
 done
}

read_dir ${CURRENTPATH}
echo ""
echo "===== total =====: "
for key in "${!name2CountArray[@]}"
do
 echo ${key} " " ${name2CountArray[${key}]}
done