# Install K8S via Kubeadm

## Install kubeadm
- Adjust docker daemon config on each node
  - change `cgroupdriver` to `systemd` 
  - `--live-restore  --exec-opt native.cgroupdriver=systemd`
  - restart docker daemon
- Install `kubeadm` on each node
  ```
  #!/bin/bash
  
  cat <<EOF > /etc/yum.repos.d/kubernetes.repo
  [kubernetes]
  name=Kubernetes
  baseurl=https://packages.cloud.google.com/yum/repos  kubernetes-el7-x86_64
  enabled=1
  gpgcheck=1
  repo_gpgcheck=1
  gpgkey=https://packages.cloud.google.com/yum/doc  yum-key.gpg https://   packages.cloud.google.com  yum/doc/rpm-package-key.gpg
  EOF
  
  # Set SELinux in permissive mode (effectively  disabling it)
  setenforce 0
  sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/'   etc/selinux/config
  
  yum install -y kubelet kubeadm kubectl  --disableexcludes=kubernetes
  
  systemctl enable --now kubelet
  
  yum install -y kubelet kubeadm kubectl  --disableexcludes=kubernetes
  systemctl enable --now kubelet
  sysctl --system
  systemctl daemon-reload
  systemctl restart kubelet
  ```

  ## Init K8S cluster
 - Init master
   ```
   swapoff -a
   kubeadm init --pod-network-cidr=192.168.0.0/16 \
     --apiserver-advertise-address=9.46.74.217 
   ```
- Init workers
  ```
  swapoff -a
  kubeadm join 9.46.74.217:6443 --token <your token> \
      --discovery-token-ca-cert-hash
  ``` 

  ## Install Helm
  - Download helm  2.15 from https://github.com/helm/helm/releases
  - `helm init --debug`
  