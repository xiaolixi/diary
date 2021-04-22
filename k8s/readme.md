

安装的版本

1. etcd 			 3.2.18
2. k8s               v1.12.10
3. docker            1.13.1
4. helm              2.9.1
5. cfssl             1.2.0

安装步骤：

1、将“二进制文件”目录下的文件拷贝到/usr/local/bin下

2、将/usr/local/bin的二进制文件变成可执行文件

```shell
[root@localhost bin]# chmod +x *
[root@localhost bin]# ll
total 814532
-rwxr-xr-x 1 root root  10376657 Jul 30 19:46 cfssl
-rwxr-xr-x 1 root root   6595195 Jul 30 19:46 cfssl-certinfo
-rwxr-xr-x 1 root root   2277873 Jul 30 19:46 cfssljson
-rwxr-xr-x 1 root root  17837888 Jul 30 19:47 etcd
-rwxr-xr-x 1 root root  15246720 Jul 30 19:47 etcdctl
-rwxr-xr-x 1 root root  30033696 Aug  4 14:59 helm
-rwxr-xr-x 1 root root  54042558 Jul  8  2019 kubeadm
-rwxr-xr-x 1 root root 192915443 Jul  8  2019 kube-apiserver
-rwxr-xr-x 1 root root 163059802 Jul  8  2019 kube-controller-manager
-rwxr-xr-x 1 root root  57361431 Jul  8  2019 kubectl
-rwxr-xr-x 1 root root 176784720 Jul  8  2019 kubelet
-rwxr-xr-x 1 root root  50327308 Jul  8  2019 kube-proxy
-rwxr-xr-x 1 root root  57195469 Jul  8  2019 kube-scheduler
[root@localhost bin]# 
```

3、运行start.sh脚本

```shell
./start.sh <ip>
```

4、各个插件安装到各自文件夹中执行install.sh脚本

~~5、helm最好还是在docker load后用helm init **** --skip-cache来安装~~

6、docker的镜像没有加私有仓库，所以安装后需要自己配置
