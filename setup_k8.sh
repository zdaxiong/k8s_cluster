##简单的通多kubeadm 实现单点k8s集群脚本
#!/bin/bash
TAG_INFO=v1.16.3
sed -i "s/Slinux=enforing/Slinux=disabled/g" /etc/selinux/config
setenforce 
#set hostname
hostnamectl set-hostname master 
cat >/etc/hosts <<EFO
127.0.0.1   localhost
::1         localhost
127.0.0.1   master
192.168.10.151 master
192.168.10.152 node01
192.168.10.151 node02
EFO
#insatll docker and kebernetes repos
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum makecache fast

#install k8s_cluster appliacations 
yum install docker-ce kubelet kubeadm kubectl -y

systemctl enable docker
systemctl enable kubelet
systemctl start docker
#speed up docker images
touch /etc/docker/daemon.json
cat >/etc/docker/daemon.json<<EFO
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}

{
  "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
EFO

echo "1">/proc/sys/net/bridge/bridge-nf-call-ip6tables
echo "1">/proc/sys/net/bridge/bridge-nf-call-iptables
systemctl restart docker

systemctl stop firewalld
iptables -F
#close swap
swapoff -a

systemctl start kubelet

docker login --username=tb130473_2013 registry.cn-chengdu.aliyuncs.com -p 

docker pull registry.cn-chengdu.aliyuncs.com/shixiong/kube-apiserver:${TAG_INFO}
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/kube-controller-manage:${TAG_INFO}
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/kube-scheduler:${TAG_INFO}
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/kube-proxy:${TAG_INFO}
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/pause:3.1
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/etcd:3.3.15-0
docker pull registry.cn-chengdu.aliyuncs.com/shixiong/coredns:1.6.2
 
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/kube-apiserver:${TAG_INFO}  k8s.gcr.io/kube-apiserver:v1.16.3
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/kube-controller-manage:${TAG_INFO}  k8s.gcr.io/kube-controller-manager:v1.16.3
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/kube-scheduler:${TAG_INFO}  k8s.gcr.io/kube-scheduler:v1.16.3
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/kube-proxy:${TAG_INFO}  k8s.gcr.io/kube-proxy:v1.16.3
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/pause:3.1 k8s.gcr.io/pause:3.1
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/etcd:3.3.15-0 k8s.gcr.io/etcd:3.3.15-0
docker tag registry.cn-chengdu.aliyuncs.com/shixiong/coredns:1.6.2 k8s.gcr.io/coredns:1.6.2
 
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/kube-apiserver:${TAG_INFO}
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/kube-controller-manage:${TAG_INFO}
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/kube-scheduler:${TAG_INFO}
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/kube-proxy:${TAG_INFO}
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/pause:3.1
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/etcd:3.3.15-0
docker rmi registry.cn-chengdu.aliyuncs.com/shixiong/coredns:1.6.2

cat >/etc/systemd/system/kubelet.service.d/10-kubeadm.conf<<EFO
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd"
Environment="KUBELET_EXTRA_ARGS=--fail-swap-on=false"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EFO

systemctl restart kubelet
cat </etc/sysconfig/kubelet <<EFO
KUBELET_EXTRA_ARGS=--fail-swap-on=false
EFO

systemctl daemon-reload 
systemctl restart kubelet

kubeadm init --kubernetes-version v1.16.3 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --ignore-preflight-errors=Swap

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#install fannel
wget  https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
kubectl apply -f kube-flannel.yml
