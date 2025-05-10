sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet/*
sudo systemctl start kubelet