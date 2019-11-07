# Install K8S via `kubeadm`
- Install `kubeadm` https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- Create a K8S cluster
  - Init a cluster
    - `kubeadm init --pod-network-cidr=192.168.0.0/16   --apiserver-advertise-address=9.46.74.217`
  - Join into K8S cluster on other node
  
  - Install Calico on each node
    - `kubectl create -f https://docs.projectcalico.org/v3.10/manifests/calico.yaml`
- add `ExecStartPre=/usr/sbin/swapoff -a` in `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` before `ExecStart=`

# Install K8S via Kubeadm

## Install kubeadm
- Reference https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
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
  baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
  enabled=1
  gpgcheck=1
  repo_gpgcheck=1
  gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
  EOF
  
  # Set SELinux in permissive mode (effectively  disabling it)
  setenforce 0
  sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/'   etc/selinux/config
  
  yum install -y kubelet kubeadm kubectl  --disableexcludes=kubernetes
  
  systemctl enable --now kubelet
  
  yum install -y kubelet kubeadm kubectl  --disableexcludes=kubernetes
  systemctl enable --now kubelet
  sysctl --system

  DROPIN=/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
  sed -i -e '/ExecStart=$/iExecPreStart=/usr/sbin/swapoff -a' $DROPIN
  systemctl daemon-reload
  systemctl restart kubelet
  systemctl status kubelet
  ```

## Init K8S cluster
 - Init master
   ```
   cat > kubeadm-init.sh <<EOF
   swapoff -a
   MASTER=$1
   kubeadm config images pull
   kubeadm init --pod-network-cidr=192.168.0.0/16 \
     --apiserver-advertise-address=$MASTER \
     --control-plane-endpoint=$MASTER \
     --node-name=$MASTER
   EOF
   bash -x kubeadm-init.sh <your master ip> 2>&1 | tee init.log
   mkdir -p $HOME/.kube
   cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
   #chown $(id -u):$(id -g) $HOME/.kube/config
   ```
- Init workers
  ```
  ABC=`tail -n 2 init.log`
  set -x; ssh 9.46.76.125 eval "swapoff -a; $ABC --node-name=9.46.76.125"; set +x
  ```
  ```
  swapoff -a
  kubeadm join 9.46.74.217:6443 --token <your token> \
      --discovery-token-ca-cert-hash \
      --node-name=9.46.74.243
  ``` 
- add `ExecStartPre=/usr/sbin/swapoff -a` 
  in `/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf` 
  before `ExecStart=`

## Install a pod network add-on
```
kubectl apply -f https://docs.projectcalico.org/v3.10/manifests/calico.yaml
```

 ## Optional - Install Kubernetes Dashboard
- Install https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/
  ```
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta4/aio/deploy/recommended.yaml
  ```
- Access Dashboard

- Login into Dashboard
  - Create a `ServiceAccount`
    ```
    kubectl create sa kubernetes-dashboard -n kube-system
    ```
  - Create `ClusterRoleBinding`
    ```
    kubectl apply -f - <<EOF
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRoleBinding
    metadata:
      name: admin-user
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-admin
    subjects:
    - kind: ServiceAccount
      name: kubernetes-dashboard
      namespace: kube-system
    EOF
    ```
  - Get token 
    ```
    kubectl -n kube-system describe secrets \
       `kubectl -n kube-system get secrets | awk '/kubernetes-dashboard/ {print $1}'` \
        | awk '/token:/ {print $2}'
    ```

 ## Optional - Install Helm
  - Download helm  2.15 from https://github.com/helm/helm/releases
  - `helm init --debug`
  
## Install NFS external storage provider  
- Clone `git@github.com:kubernetes-incubator/external-storage.git`
- Apply patch
  - Change docker image from `gcr.io` do `dockeri.o`
  - Make NFS storage class default
  - Adopt `apiVersion` to `kubeadm` cluster
  ```
  cd external-storage/nfs/deploy/kubernetes
  cat > k8s.patch  <<EOF
  diff --git a/nfs/deploy/kubernetes/class.yaml b/nfs/deploy/     kubernetes/class.yaml
  index 582d0f1..5bc2203 100644
  --- a/nfs/deploy/kubernetes/class.yaml
  +++ b/nfs/deploy/kubernetes/class.yaml
  @@ -1,6 +1,8 @@
   kind: StorageClass
   apiVersion: storage.k8s.io/v1
   metadata:
  +  annotations:
  +    storageclass.kubernetes.io/is-default-class: "true"
     name: example-nfs
   provisioner: example.com/nfs
   mountOptions:
  diff --git a/nfs/deploy/kubernetes/psp.yaml b/nfs/deploy/kubernetes/     psp.yaml
  index 2f8e188..03fd080 100644
  --- a/nfs/deploy/kubernetes/psp.yaml
  +++ b/nfs/deploy/kubernetes/psp.yaml
  @@ -1,4 +1,4 @@
  -apiVersion: extensions/v1beta1
  +apiVersion: policy/v1beta1
   kind: PodSecurityPolicy
   metadata:
     name: nfs-provisioner
  diff --git a/nfs/deploy/kubernetes/read-pod.yaml b/nfs/deploy/     kubernetes/read-pod.yaml
  index 31497e9..1c4e0f2 100644
  --- a/nfs/deploy/kubernetes/read-pod.yaml
  +++ b/nfs/deploy/kubernetes/read-pod.yaml
  @@ -5,7 +5,7 @@ metadata:
   spec:
     containers:
     - name: read-pod
  -    image: gcr.io/google_containers/busybox:1.24
  +    image: docker.io/library/busybox:1.24
       command:
         - "/bin/sh"
       args:
  diff --git a/nfs/deploy/kubernetes/write-pod.yaml b/nfs/deploy/     kubernetes/write-pod.yaml
  index 99f7d02..e6c3fb4 100644
  --- a/nfs/deploy/kubernetes/write-pod.yaml
  +++ b/nfs/deploy/kubernetes/write-pod.yaml
  @@ -5,7 +5,7 @@ metadata:
   spec:
     containers:
     - name: write-pod
  -    image: gcr.io/google_containers/busybox:1.24
  +    image: docker.io/library/busybox:1.24
       command:
         - "/bin/sh"
       args:
  EOF

  patch -i k8s.patch
  ```