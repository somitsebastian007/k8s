ubuntu@ip-172-31-21-77:~/k8s$ sh kubeadm-cluster-setup-master-only.sh
[Step 0] Stop unattended-upgrades to prevent interference
Synchronizing state of unattended-upgrades.service with SysV service script with /lib/systemd/systemd-sysv-install.
Executing: /lib/systemd/systemd-sysv-install disable unattended-upgrades
[Step 0.1] Configure debconf to suppress prompts
[Step 1] Update and upgrade system packages
linux-image-6.8.0-1024-aws was already set on hold.
linux-headers-6.8.0-1024-aws was already set on hold.
linux-aws was already set on hold.
dpkg: error: illegal package name at line 1: illegal package name in specifier 'linux-image-*': character '*' not allowed (only letters, digits and characters '-+._')