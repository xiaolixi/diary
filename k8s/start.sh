#！/bin/sh
path=$(cd $(dirname $0) && pwd) 

usage() {
	echo "usage: $0 ip地址"
	echo ""
}

if [ $# -ne 1 ];then
	usage
	exit 1
fi

which cfssl 
if [ $? -ne 0 ];then
	echo "请将二进制文件放到/usr/local/bin的目录，并加上可执行权限"
	exit 1
fi

if [ ! -e ${path}/pause-amd64-3.0.tar ];then
	echo "请将pause-amd64-3.0.tar放在与脚本同级目录下"
	exit 1
fi


systemctl stop kube-proxy
systemctl stop kubelet
systemctl stop docker
systemctl stop kube-scheduler
systemctl stop kube-controller-manager
systemctl stop kube-apiserver
systemctl stop etcd

set -e
masterIP="$1"

systemctl disable firewalld && systemctl stop firewalld

if [ `getenforce` != Disabled ];then
 setenforce 0
fi
sed -i 's/^SELINUX=enforcing$/SELINUX=disable/' /etc/selinux/config

#关闭swap
swapoff -a 
sed -i 's/.*swap.*/#&/g' /etc/fstab

echo 1 > /proc/sys/net/ipv4/ip_forward
#sysctl -w net.ipv4.ip_forward=1

cat > /etc/sysctl.conf <<EOF
net.ipv4.ip_forward=1
EOF

if [ -f /etc/yum.repos.d/CentOS-Base.repo ];then
	mv /etc/yum.repos.d/CentOS-Base.repo     /etc/yum.repos.d/CentOS-Base.repo_back
fi
cat > /etc/yum.repos.d/local.repo << EOF
[local]
name=local
baseurl=http://192.168.11.200:8099/repo/
gpgcheck=0
enabled=1
EOF

yum clean all
yum install -y conntrack-tools socat vim


# 生成CA证书
rm -rf /root/ssl/*
mkdir -p /root/ssl/
cd /root/ssl/

cat > /root/ssl/ca-config.json << EOF
{
    "signing": {
        "default": {
            "expiry": "175200h"
        },
        "profiles": {
            "kubernetes": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
EOF

cat > /root/ssl/ca-csr.json<<EOF
{
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Wuhan",
            "ST": "Hubei",
    	    "O": "k8s",
    	    "OU": "System"
        }
    ]
}
EOF

# 生成CA证书：
cfssl gencert --initca=true /root/ssl/ca-csr.json | cfssljson --bare ca

echo "生成CA证书结束"
sleep 2

# 生成Kubernetes master节点使用的证书
cat  > /root/ssl/kubernetes-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
        "127.0.0.1",
        "localhost",
        "${masterIP}",
        "10.254.0.1",
        "kubernetes",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster",
        "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "Hubei",
            "L": "Wuhan",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# 生成kubernetes证书：

cfssl gencert --ca /root/ssl/ca.pem --ca-key /root/ssl/ca-key.pem --config /root/ssl/ca-config.json --profile kubernetes /root/ssl/kubernetes-csr.json | cfssljson --bare kubernetes

echo "生成kubernetes证书结束"
sleep 2

# 生成kubectl证书
cat > /root/ssl/admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Hubei",
      "L": "Wuhan",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF



# 生成kubectl证书：
cfssl gencert --ca /root/ssl/ca.pem --ca-key /root/ssl/ca-key.pem --config /root/ssl/ca-config.json --profile kubernetes /root/ssl/admin-csr.json | cfssljson --bare admin

echo "生成kubectl证书结束"
sleep 2
# 生成kube-proxy证书

cat > /root/ssl/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Hubei",
      "L": "Wuhan",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF


# 生成kube-proxy证书：


cfssl gencert --ca /root/ssl/ca.pem --ca-key /root/ssl/ca-key.pem --config /root/ssl/ca-config.json --profile kubernetes /root/ssl/kube-proxy-csr.json | cfssljson --bare kube-proxy
echo "生成kube-proxy证书结束"
sleep 2
# 将所有证书复制到/etc/kubernete/ssl目录下：
rm -rf /etc/kubernetes/ssl/*
mkdir -p /etc/kubernetes/ssl
\cp -rf /root/ssl/*.pem /etc/kubernetes/ssl/


# 生成token及kubeconfig
# 在本次配置中，我们将会同时启用证书认证，token认证，以及http basic认证。所以需要提前生成token认证文件，
# basic认证文件以及kubeconfig
# 
# 以下所有操作都直接在/etc/kubernetes目录进行

cd  /etc/kubernetes
# 生成token文件
export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > /etc/kubernetes/bootstrap-token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF


# 生成http basic认证文件
cat > /etc/kubernetes/basic-auth.csv <<EOF
admin,admin,1
EOF

# 生成用于kubelet认证使用的bootstrap.kubeconfig文件
export KUBE_APISERVER="https://${masterIP}:6443"
# 设置集群参数，即api-server的访问方式，给集群起个名字就叫kubernetes
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig
  
# 设置客户端认证参数，这里采用token认证
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# 设置上下文参数，用于连接用户kubelet-bootstrap与集群kubernetes
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig
  
# 设置默认上下文
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

# 生成kube-proxy使用的kube-proxy.kubeconfig文件
# 设置集群参数
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig
# 设置客户端认证参数
kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# k8s kubelet 生成kube-config文件
# kubectl config set-cluster kubernetes \
#   --certificate-authority=/etc/kubernetes/ssl/ca.pem \
#   --server=https://${masterIP}:6443 \
#   --kubeconfig=kubelet.kubeconfig
# kubectl config set-credentials kubelet \
#   --client-certificate=/etc/kubernetes/ssl/kubelet-1-71.pem -\
#   -client-key=/etc/kubernetes/ssl/kubelet-1-71.key \
#   --kubeconfig=kubelet.kubeconfig
# kubectl config set-context default \
#   --cluster=kubernetes \
#   --user=kubelet \
#   --kubeconfig=kubelet.kubeconfig
# kubectl config use-context default --kubeconfig=kubelet.kubeconfig


cat > kubelet.config << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: ${masterIP}
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: false
EOF


echo "生成config证书结束"
sleep 2

# 部署etcd
# 我们已经提前下载好所有组件的二进制文件，并且全部拷贝到了/usr/local/bin目录下。所以这里只配置各服务相关的启动文件。
# 
# 创建etcd的启动文件/etc/systemd/system/etcd.service，内容如下：
# 

mkdir -p /usr/lib/systemd/system/
cat > /usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd
After=network.target
Before=flanneld.service

[Service]
User=root
ExecStart=/usr/local/bin/etcd \
-name etcd1 \
-data-dir /var/lib/etcd \
--advertise-client-urls http://${masterIP}:2379,http://127.0.0.1:2379 \
--listen-client-urls http://${masterIP}:2379,http://127.0.0.1:2379
Restart=on-failure
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 启动etcd:

systemctl daemon-reload
systemctl start etcd
systemctl enable etcd
systemctl status etcd
echo "etcd结束"
sleep 2

# 部署master
# kube-apiserver
# 创建kube-apiserver的启动文件/usr/lib/systemd/system/kube-apiserver.service，内容如下：
cat > /usr/lib/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/usr/local/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,PersistentVolumeLabel,DefaultStorageClass,ResourceQuota,DefaultTolerationSeconds,NodeRestriction \
  --apiserver-count=3 \
  --bind-address=${masterIP} \
  --insecure-bind-address=127.0.0.1 \
  --insecure-port=8080 \
  --secure-port=6443 \
  --authorization-mode=Node,RBAC \
  --runtime-config=rbac.authorization.k8s.io/v1 \
  --kubelet-https=true \
  --anonymous-auth=false \
  --basic-auth-file=/etc/kubernetes/basic-auth.csv \
  --enable-bootstrap-token-auth \
  --token-auth-file=/etc/kubernetes/bootstrap-token.csv \
  --service-cluster-ip-range=10.254.0.0/16 \
  --service-node-port-range=20000-40000 \
  --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem \
  --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
  --client-ca-file=/etc/kubernetes/ssl/ca.pem \
  --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --etcd-servers=http://${masterIP}:2379 \
  --etcd-quorum-read=true \
  --enable-swagger-ui=true \
  --allow-privileged=true \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/var/log/kube-apiserver-audit.log \
  --event-ttl=1h \
  --v=2 \
  --logtostderr=true
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


# 启动kube-apiserver：

systemctl daemon-reload
systemctl start kube-apiserver
systemctl enable kube-apiserver
systemctl status kube-apiserver

echo "apiserver结束"
sleep 2
# kube-controller-manager
# 创建kube-controller-manager的启动文件/usr/lib/systemd/system/kube-controller-manager.service，内容如下：

cat > /usr/lib/systemd/system/kube-controller-manager.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --cluster-name=kubernetes \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --service-cluster-ip-range=10.254.0.0/16 \
  --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/etc/kubernetes/ssl/ca.pem \
  --node-monitor-grace-period=40s \
  --node-monitor-period=5s \
  --pod-eviction-timeout=5m0s \
  --controllers=*,bootstrapsigner,tokencleaner \
  --horizontal-pod-autoscaler-use-rest-clients=false \
  --leader-elect=true \
  --v=2 \
  --logtostderr=true

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#启动kube-controller-manager服务：

systemctl daemon-reload
systemctl start kube-controller-manager
systemctl enable kube-controller-manager
systemctl status kube-controller-manager
echo "controller结束"
sleep 2

# kube-scheduler
# 创建kube-scheduler的启动文件/usr/lib/systemd/system/kube-scheduler.service，内容如下：
cat > /usr/lib/systemd/system/kube-scheduler.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --leader-elect=true \
  --v=2 \
  --logtostderr=true

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#启动kube-scheduler:

systemctl daemon-reload
systemctl start kube-scheduler
systemctl enable kube-scheduler
systemctl status kube-scheduler
echo "scheduler结束"
sleep 2
# 配置rbac授权
# 绑定kubelet-bootstrap用户到system:node-bootstrapper权限组

if [ `kubectl get clusterrolebinding  | grep kubelet-bootstrap-clusterbinding | wc -l` -eq 1 ];then
	kubectl delete clusterrolebinding kubelet-bootstrap-clusterbinding
fi
kubectl create clusterrolebinding kubelet-bootstrap-clusterbinding --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap

# 绑定system:nodes组到system:node权限组
if [ `kubectl get clusterrolebinding  | grep kubelet-node-clusterbinding | wc -l` -eq 1 ];then
	kubectl delete clusterrolebinding kubelet-node-clusterbinding
fi
kubectl create clusterrolebinding kubelet-node-clusterbinding --clusterrole=system:node --group=system:nodes


# 部署Node

# docker1.13.1
yum install -y docker
sed -i 's|native.cgroupdriver=systemd|native.cgroupdriver=cgroupfs|'  /usr/lib/systemd/system/docker.service 
sed -i 's|^OPTIONS|#OPTIONS|' /etc/sysconfig/docker
#OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false'
lastOPTIONSLine=` grep -n  "OPTIONS" /etc/sysconfig/docker | tail -n 1 | awk -F ":" '{print $1}'`
sed -i "${lastOPTIONSLine}a\OPTIONS='--selinux-enabled  -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --live-restore --oom-score-adjust=-999 --log-driver=json-file --log-opt max-size=16m --log-opt max-file=2 --signature-verification=false'" /etc/sysconfig/docker
systemctl daemon-reload
systemctl start docker
systemctl status docker
systemctl enable docker
docker load -i ${path}/pause-amd64-3.0.tar

# kubelet
#创建kubelet的启动文件/usr/lib/systemd/system/kubelet.service，内容如下：
#加上了--runtime-cgroups=/systemd/system.slice   --kubelet-cgroups=/systemd/system.slice 
cat > /usr/lib/systemd/system/kubelet.service<<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
#WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet \
  --runtime-cgroups=/systemd/system.slice \
  --kubelet-cgroups=/systemd/system.slice \
  --address=${masterIP} \
  --hostname-override=${masterIP} \
  --cgroup-driver=cgroupfs \
  --pod-infra-container-image=mirrorgooglecontainers/pause-amd64:3.0 \
  --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig \
  --kubeconfig=/etc/kubernetes/kubelet.kubeconfig \
  --cert-dir=/etc/kubernetes/ssl \
  --cluster-dns=10.254.0.100 \
  --cluster-domain=cluster.local. \
  --hairpin-mode=promiscuous-bridge \
  --allow-privileged=true \
  --fail-swap-on=false \
  --serialize-image-pulls=false \
  --max-pods=30 \
  --logtostderr=true \
  --v=2 
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# 启动kubelet：

systemctl daemon-reload
systemctl start kubelet
systemctl enable kubelet
systemctl status kubelet
echo "kubelet结束"
sleep 2
# 在master上为kubelet颁发证书：

# node节点正常启动以后，在master端执行kubectl get nodes看不到node节点，这是因为node节点启动后先向master申请证书，
# master签发证书以后，才能加入到集群中，如下：

# 查看 csr
kubectl get csr
csrName=`kubectl get csr | grep -v NAME | awk '{print $1}'`
#NAME        AGE       REQUESTOR           CONDITION
#csr-l9d25   2m        kubelet-bootstrap   Pending
sleep 2
# 签发证书
kubectl certificate approve ${csrName}
# certificatesigningrequest "csr-l9d25" approved

sleep 2
#[root@localhost ~]# kubectl get csr
#NAME                                                   AGE     REQUESTOR           CONDITION
#node-csr-ubBZwOz9OB8uNtNI8bVzBWJclQtb0ZPyflRsyH3J128   5m29s   kubelet-bootstrap   Approved,Issued


#这时，在master上执行kubectl get nodes就可以看到一个node节点：
# 查看 node
kubectl get node
# NAME          STATUS    AGE       VERSION
# 192.168.198.135   Ready     3m        v1.11.1


# kube-proxy
# 创建kube-proxy的启动文件/usr/lib/systemd/system/kube-proxy.service，内容如下：
cat > /usr/lib/systemd/system/kube-proxy.service <<EOF
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
#WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/local/bin/kube-proxy \
  --bind-address=${masterIP} \
  --hostname-override=${masterIP} \
  --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig \
  --v=2 \
  --cluster-cidr=10.254.0.0/16

Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

# 启动kube-proxy:
systemctl daemon-reload
systemctl start kube-proxy
systemctl enable kube-proxy
systemctl status kube-proxy
echo "proxy结束"
sleep 2

kubectl get node


if [[ $(grep "/usr/local/bin/kubectl" /etc/profile | wc -l) = 0 ]];then

	echo "
	alias pod='/usr/local/bin/kubectl  get --all-namespaces pod -o wide'
	alias rc='/usr/local/bin/kubectl  get --all-namespaces rc'
	alias svc='/usr/local/bin/kubectl  get --all-namespaces svc'
	alias desc_pod='/usr/local/bin/kubectl describe pod'
	alias desc_rc='/usr/local/bin/kubectl  describe rc'
	alias desc_svc='/usr/local/bin/kubectl describe svc'
	alias dimg='docker images'  
	alias etcd-health='/usr/local/bin/etcdctl cluster-health'
	alias etcd-ls='/usr/local/bin/etcdctl ls --recursive' 
	" >> /etc/profile

fi

source /etc/profile

echo "安装完成"
svc
