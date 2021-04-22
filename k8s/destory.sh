#！/bin/sh

systemctl stop kube-proxy
systemctl stop kubelet
systemctl stop docker
systemctl stop kube-scheduler
systemctl stop kube-controller-manager
systemctl stop kube-apiserver
systemctl stop etcd

systemctl disable kube-proxy
systemctl disable kubelet
systemctl disable docker
systemctl disable kube-scheduler
systemctl disable kube-controller-manager
systemctl disable kube-apiserver
systemctl disable etcd


\rm -f /usr/lib/systemd/system/etcd.service
\rm -f /usr/lib/systemd/system/kube-apiserver.service
\rm -f /usr/lib/systemd/system/kube-controller-manager.service  
\rm -f /usr/lib/systemd/system/kube-scheduler.service 
\rm -f /usr/lib/systemd/system/kubelet.service
\rm -f /usr/lib/systemd/system/kube-proxy.service

yum remove docker
yum remove -y conntrack-tools socat vim

\rm -rf /root/ssl
\rm -rf /etc/kubernetes
