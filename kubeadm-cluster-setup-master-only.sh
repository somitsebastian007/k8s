#!/bin/bash
set -e

# Make the script non-interactive to suppress prompts
export DEBIAN_FRONTEND=noninteractive

# Accept service restarts automatically during package upgrades
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

echo "[Step 1] Update and upgrade system packages"
sudo apt update && sudo apt upgrade -yq
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

echo "[Step 6] Configure networking modules and sysctl"
sudo modprobe br_netfilter
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "[Step 7] Check if system needs reboot"
if [ -f /var/run/reboot-required ]; then
    echo "System requires reboot to apply changes. Rebooting now..."
    sudo reboot
fi

# IMPORTANT:
# Run the following steps ONLY on the MASTER NODE after reboot or log back in

if [[ "$1" == "master" ]]; then
    echo "[MASTER NODE ONLY] Initializing Kubernetes cluster"
    sudo kubeadm init --pod-network-cidr=192.168.0.0/16

    echo "[MASTER NODE ONLY] Configuring kubectl for the current user"
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    echo "Kubernetes Master Node is set up. You can now join worker nodes using the kubeadm join command."
else
    echo "Worker node preparation complete. Wait for the master to provide the join command."
fi

# Install a CNI plugin (on master)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml