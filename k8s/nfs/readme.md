参考文档：https://blog.csdn.net/networken/article/details/86697018
https://blog.csdn.net/Ay_Ly/article/details/105141566
https://www.kubernetes.org.cn/3894.html


1、找一个服务端安装nfs服务
centos7 
```
# yum -y install nfs-utils
# mkdir /data/k8s/sc  -pv
# vim /etc/exports
# /data/k8s/sc   192.168.11.0/24(insecure,rw,async,no_root_squash)
# systemctl enable nfs
# systemctl start nfs
# exportfs
# showmount -a localhost
# showmount -e localhost
```




2、k8s节点安装nfs-utils但是不必开启，应该只是需要nfs的库
```
yum install nfs-common  nfs-utils -y 
```
```
Events:
  Type     Reason            Age                 From                    Message
----     ------            ----                ----                    -------
  Warning  FailedScheduling  70s (x25 over 92s)  default-scheduler       persistentvolumeclaim "qisubo-data" not found
  Warning  FailedMount       55s                 kubelet, 192.168.0.241  MountVolume.SetUp failed for volume "pvc-d23f8253-7a2b-11ea-9efc-fa163e0a3c50" : mount failed: exit status 32
Mounting command: systemd-run
Mounting arguments: --description=Kubernetes transient mount for /var/lib/kubelet/pods/c4bbba84-7a2b-11ea-9efc-fa163e0a3c50/volumes/kubernetes.io~nfs/pvc-d23f8253-7a2b-11ea-9efc-fa163e0a3c50 --scope -- mount -t nfs 192.168.0.103:/data/protected/meapp10494-opt-disk-pvc-d23f8253-7a2b-11ea-9efc-fa163e0a3c50 /var/lib/kubelet/pods/c4bbba84-7a2b-11ea-9efc-fa163e0a3c50/volumes/kubernetes.io~nfs/pvc-d23f8253-7a2b-11ea-9efc-fa163e0a3c50
Output: Running scope as unit run-15340.scope.
mount: wrong fs type, bad option, bad superblock on 192.168.0.103:/data/protected/meapp10494-opt-disk-pvc-d23f8253-7a2b-11ea-9efc-fa163e0a3c50,
       missing codepage or helper program, or other error
       (for several filesystems (e.g. nfs, cifs) you might
       need a /sbin/mount.<type> helper program)

       In some cases useful info is found in syslog - try
       dmesg | tail or so.
```
3、运行yaml
```
kubectl create -f ./
```
4、测试

### server

```yaml
[root@localhost ~]# ls /data/k8s/sc/
default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265
[root@localhost ~]# 
[root@localhost ~]# ls /data/k8s/sc/default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265/
test.txt
[root@localhost ~]# cat /data/k8s/sc/default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265/test.txt 
hello
[root@localhost ~]# showmount -a localhost
All mount points on localhost:
[root@localhost ~]# 
[root@localhost ~]# ll /data/k8s/sc
total 0
drwxrwxrwx 2 root root 22 Aug 11 18:26 default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265
[root@localhost ~]# 
[root@localhost ~]# ll /data/k8s
total 0
drwxr-xr-x 3 root root 71 Aug 11 18:26 sc
```

### k8s

```shell
[root@localhost nfs-storage]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS      REA
SON   AGEos-nfs-volume                              10Gi       RWX            Retain           Bound    default/os-nfs-volume                        
      132mpvc-a302cfc0-dbba-11ea-b268-0cda411d2265   1Mi        RWX            Delete           Bound    default/test-pvc        k8s-nfs-storage      
      5m35s[root@localhost nfs-storage]# 
```

```
[root@localhost nfs-storage]# kubectl get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
os-nfs-volume   Bound    os-nfs-volume                              10Gi       RWX                              141m
test-pvc        Bound    pvc-a302cfc0-dbba-11ea-b268-0cda411d2265   1Mi        RWX            k8s-nfs-storage   14m

```

存储卷是

- PV以 `${namespace}-${pvcName}-${pvName}`的命名格式提供（在NFS服务器上）
- PV回收的时候以 `archieved-${namespace}-${pvcName}-${pvName}` 的命名格式（在NFS服务器上）

## 删除后

```yaml
[root@localhost nfs-storage]# kubectl delete pod test-pod
pod "test-pod" deleted

[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# kubectl get pvc
NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
os-nfs-volume   Bound    os-nfs-volume                              10Gi       RWX                              144m
test-pvc        Bound    pvc-a302cfc0-dbba-11ea-b268-0cda411d2265   1Mi        RWX            k8s-nfs-storage   17m
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# kubectl delete pvc test-pvc
persistentvolumeclaim "test-pvc" deleted
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# kubectl get pvc
NAME            STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS   AGE
os-nfs-volume   Bound    os-nfs-volume   10Gi       RWX                           145m
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# kubectl get pv
NAME            CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                   STORAGECLASS   REASON   AGE
os-nfs-volume   10Gi       RWX            Retain           Bound    default/os-nfs-volume                           145m
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 
[root@localhost nfs-storage]# 

```

服务端

```
[root@localhost ~]# ll /data/k8s/sc
total 0
drwxrwxrwx 2 root root 22 Aug 11 18:26 archived-default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265
[root@localhost ~]# 
[root@localhost ~]# 
[root@localhost ~]# 
[root@localhost ~]# ll /data/k8s/sc/archived-default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265/
total 4
-rw-r--r-- 1 root root 6 Aug 11 18:26 test.txt
[root@localhost ~]# ll /data/k8s/sc/archived-default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265/test.txt 
-rw-r--r-- 1 root root 6 Aug 11 18:26 /data/k8s/sc/archived-default-test-pvc-pvc-a302cfc0-dbba-11ea-b268-0cda411d2265/test.txt

```



