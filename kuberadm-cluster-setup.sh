# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl apt-transport-https ca-certificates gnupg lsb-release

# Install Docker (on both nodes)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
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

# Load the br_netfilter module (on both)
sudo modprobe br_netfilter

# Ensure it loads on boot (on both)
echo "br_netfilter" | sudo tee /etc/modules-load.d/k8s.conf
sleep 10

# Set required sysctl parameters (on both)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply changes (on both):
sudo sysctl --system

###### Fix for bridge-nf-call-iptables does not exist ###### END ###

#### MASTER NODE ONLY #### START ###

# Initialize Kubernetes (on master node only)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Configure kubectl access for your user (on master only):
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install a CNI plugin (on master)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml

# Perform kubectl command
kubectl get nodes

# On worker Node::::::
# sudo kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Download kubectl 1.32 on windows:::::
# curl.exe -LO "https://dl.k8s.io/release/v1.32.0/bin/windows/amd64/kubectl.exe"

# Download kubectl 1.29 on windows:::::
# curl.exe -LO "https://dl.k8s.io/release/v1.29.0/bin/windows/amd64/kubectl.exe"

# Access from local host ::::
#  kubectl get ns --insecure-skip-tls-verify

# Downlaod OpenLens IDE OpenSource ::::
# https://github.com/MuhammedKalkan/OpenLens/releases





