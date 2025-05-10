#!/bin/bash
set -e

# Make the script non-interactive to suppress prompts
export DEBIAN_FRONTEND=noninteractive

# Stop unattended-upgrades to prevent interference
echo "[Step 0] Stop unattended-upgrades to prevent interference"
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades --now

# Configure debconf to suppress service restart prompts
echo "[Step 0.1] Configure debconf to suppress prompts"
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo 'libc6 libraries/restart-without-asking boolean true' | sudo debconf-set-selections
echo 'libpam0g libraries/restart-without-asking boolean true' | sudo debconf-set-selections

echo "[Step 1] Update and upgrade system packages"
# Explicitly hold the current kernel packages (AWS-specific)
sudo apt-mark hold linux-image-$(uname -r)
sudo apt-mark hold linux-headers-$(uname -r)
sudo apt-mark hold linux-aws

# Exclude kernel packages from upgrade
echo "linux-image-* hold" | sudo dpkg --set-selections
echo "linux-headers-* hold" | sudo dpkg --set-selections
echo "linux-aws* hold" | sudo dpkg --set-selections

# Update and upgrade with additional non-interactive flags
sudo apt update
sudo apt upgrade -yq --allow-downgrades --allow-remove-essential --allow-change-held-packages

# Install required packages
sudo apt install -yq curl apt-transport-https ca-certificates gnupg lsb-release debconf-utils

echo "[Step 2] Install Docker dependencies and repo"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -yq docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

echo "[Step 3] Configure containerd"
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "[Step 4] Disable swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

echo "[Step 5] Add Kubernetes apt repo"
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -yq kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "[Step 5.1] Restart services that might be using outdated libraries"
sudo systemctl restart dbus.service
sudo systemctl restart irqbalance.service
sudo systemctl restart multipathd.service
sudo systemctl restart networkd-dispatcher.service
sudo systemctl restart packagekit.service
sudo systemctl restart polkit.service
sudo systemctl restart systemd-logind.service
sudo systemctl restart unattended-upgrades.service || true
sudo systemctl restart user@1000.service || true

echo "[Step 6] Configure networking modules and sysctl"
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "[Step 7] Initializing Kubernetes cluster"
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

echo "[Step 8] Configuring kubectl for the current user"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "[Step 9] Install Calico CNI plugin"
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

echo "Kubernetes Master Node is set up. You can now join worker nodes using the kubeadm join command."

# Re-enable unattended-upgrades
echo "[Step 10] Re-enable unattended-upgrades"
sudo systemctl enable unattended-upgrades
sudo systemctl start unattended-upgrades