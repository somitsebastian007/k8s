# Update and install dependencies (on both nodes)
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release

# Install Docker (on both nodes)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER

# Configure containerd (on both)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# Disable swap (on both)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Install kubeadm, kubelet, kubectl (on both)
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

###### Fix for bridge-nf-call-iptables does not exist ###### START ###

# These commands are part of the prerequisites for setting up Kubernetes (typically when using 
# kubeadm on Linux). They configure kernel modules and networking parameters to allow proper packet 
# forwarding and firewalling.

# Load the br_netfilter module (on both)
sudo modprobe br_netfilter

# Ensure it loads on boot (on both)
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
# sleep 10

# Set required sysctl parameters (on both)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply changes (on both):
sudo sysctl --system