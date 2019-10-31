# Install Argo env on K8S cluster from scratch 
## Setup Env
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

## Configure ArgoCD Env
- Update argocd password
  - find `argocd-server` service
    - `kubectl get svc -n argocd`
  - find `argocd-server` pod
    - `kubectl get po -n argocd -l app.kubernetes.io/name=argocd-server`
  - login to `argocd-server`
    - argocd login `<svc-external-ip>`
    - username: `admin`
    - password: `<argo-server-pod-name>`
  - update password
    - `argocd account update-password`
- Access to ArgoCD UI
  - check nginx ingress node port 
      - `kubectl get svc -n argocd argocd-server`
  - `http://argo-ui.<master node ip>:<argocd-server node port>/`
      - for example: https://9.46.74.217:30367   user: admin pass: admin
- Add github.ibm.com repository
  - for example:
    ```
    argocd repo add git@github.ibm.com:yangboh/argocd-example-apps.git \
        --ssh-private-key-path <path to your ssh private-key> \
        --insecure-ignore-host-key
    ```
## Deploy application
- Deploy
  ```
  argocd app create incident-expo -\
      -repo git@github.ibm.com:yangboh/argocd-example-apps.git \
      --path incident-expose \
      --dest-server https://kubernetes.default.svc   \
      --dest-namespace default  \
      --values values-kubeadm.yaml \
      --revision david
  ```
- List apps
  - `argocd app list`
- Get app info
  - `argocd app get incident-expo`
- Sync app
  - `argocd app sync incident-expo`

## Configure Argo workflow env
  - Acess Argo UI
    - check nginx ingress node port 
      - `kubectl get svc -n ingress-nginx`
    - access argo ui
      - `http://argo-ui.<master node ip>.nip.io:<nginx node port>/`
      - for example: http://argo-ui.9.46.74.217.nip.io:31022/
