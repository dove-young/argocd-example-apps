# Install Argo env on K8S cluster from scratch 

- Install Ansible
  - `yum install ansible git -y`
- Install `kubeadm` and init a K8S cluster
  - `ansible-playbook -i hosts.local k8s-init.yaml -vv`
- Check K8S cluster
  - `kubectl get node`
  - `kubectl get po --all-namespaces`
- Install K8S addons
  - `ansible-playbook -i hosts.local k8s-addons.yaml -vv`
  - take notes on K8S dashboard login token
- Install ArgoCD and Argo workflow
  - `ansible-playbook -i hosts.local argo-install.yaml -vv`