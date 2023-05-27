#!/bin/bash -e

# Installing a container runtime 
# Ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
## containerd and runc from docker repository
echo -e "Install containerd..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y containerd.io

# Configure cgroup drivers 
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#systemd-cgroup-driver
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
   [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

# Configure crictl
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

# Installing kubeadm, kubelet, kubectl and cni-plugin 
# Ref: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl
echo -e "Install kubeadm and others..."

mkdir -p /etc/apt/keyrings
sudo apt-get install -y apt-transport-https ca-certificates curl
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --yes --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl kubernetes-cni
sudo apt-mark hold kubelet kubeadm kubectl kubernetes-cni

# Configure prerequisites 
# Ref: https://kubernetes.io/docs/setup/production-environment/container-runtimes/#install-and-configure-prerequisites
echo -e "Configure os settings..."

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Install tools
echo -e "Install utility tools..."
sudo apt-get -y install etcd-client jq
sudo add-apt-repository -y ppa:rmescandon/yq
sudo apt update
sudo apt install -y yq

# Reload configuration and Restart daemon
echo -e "Reload and Restart daemons..."
sudo sysctl -p
sudo systemctl daemon-reload
sudo systemctl restart kubelet
sudo systemctl restart containerd.service

# Configure bash
echo -e "Configure os settings..."
echo "source <(kubectl completion bash)" >> /home/ubuntu/.bashrc
echo "alias k=kubectl" >> /home/ubuntu/.bashrc
echo "complete -o default -F __start_kubectl k" >> /home/ubuntu/.bashrc

echo -e "Setup has been completed."

# Version info
echo -e "\n- containerd:"
containerd -v

echo -e "\n- runc:"
runc --version

echo -e "\n- crictl:"
crictl -v

echo -e "\n- kubectl:"
kubectl version --short --client=true 2>/dev/null

echo -e "\n- kubelet:"
kubelet --version

echo -e "\n- kubeadm:"
kubeadm version