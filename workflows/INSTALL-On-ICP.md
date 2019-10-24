# Prepare a local docker registry
- We use a separate local docker registry instead of `mycluster.icp:8500`
  - Its easy to manage and maintain, including clean up images
  - Its easy to be accessed via IP address, so DNS resolve is not necessary
    - K8S DNS does not resolve `mycluster.icp` inside containers
  - Fancy web interface
- Prepare a local docker registry -- optional
  - pick up a VM
    ```
    mkdir -p /mnt/registry
    docker run -d -p 5000:5000 --restart=always \
            -v /mnt/registry:/var/lib/registry \
            --name registry-srv registry:2
    
    docker run -d -p 8080:8080 --name registry-web \
            --link registry-srv \
            -e REGISTRY_URL=http://registry-srv:5000/v2 \
            -e REGISTRY_NAME=localhost:5000 \
            hyper/docker-registry-web
    ```
  - Access UI
    - `http://<registry-ip-address>:8080/`
- Configure all your ICP node treat this registry as insecure
  ```
  cat /etc/docker/daemon.json
  {
    "insecure-registries" : ["<registry-ip-address>:5000"]
  }
  ```

# Install ArgoCD Server
- Download `install.yaml` from https://github.com/argoproj/argo-cd/releases/tag/v1.2.3
  - ` wget https://raw.githubusercontent.com/argoproj/argo-cd/v1.2.3/manifests/install.yaml -O argocd-1.2.3-install.yaml`
  - prepare patch for ICP env
    - replace `9.46.78.15` to an ICP node IP in your env
    ```
    cat > argocd-1.2.3.patch <<EOF
    --- argocd-1.2.3-install.yaml	2019-10-16 22:14:03.627716050 -0700
    +++ argocd-1.2.3-install-icp.yaml	2019-10-16 22:17:34.049492525 -0700
    @@ -2452,7 +2452,7 @@
     roleRef:
       apiGroup: rbac.authorization.k8s.io
       kind: ClusterRole
    -  name: argocd-application-controller
    +  name: cluster-admin
     subjects:
     - kind: ServiceAccount
       name: argocd-application-controller
    @@ -2469,7 +2469,7 @@
     roleRef:
       apiGroup: rbac.authorization.k8s.io
       kind: ClusterRole
    -  name: argocd-server
    +  name: ibm-anyuid-clusterrole
     subjects:
     - kind: ServiceAccount
       name: argocd-server
    @@ -2636,6 +2636,8 @@
         port: 443
         protocol: TCP
         targetPort: 8080
    +  externalIPs:
    +  - 9.46.78.15
       selector:
         app.kubernetes.io/name: argocd-server
     ---
    @@ -2758,6 +2760,8 @@
             name: redis
             ports:
             - containerPort: 6379
    +      securityContext:
    +        runAsUser: 999
     ---
     apiVersion: apps/v1
     kind: Deployment
    EOF
    ```
    - Apply patch
      - `patch argocd-1.2.3-install.yaml argocd-1.2.3.patch`
    - Create `clusterimagepolicy`
    ```
    cat > argo-clusterimagepolicy.yaml <<EOF
    apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
    kind: ClusterImagePolicy
    metadata:
      labels:
        release: argo
      name: argo-image-policy
    
    spec:
      repositories:
      - name: 9.46.76.93:5000/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
      - name: gcr.io/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
      - name: mycluster.icp:8500/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
      - name: docker.io/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
      - name: quay.io/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
      - name: k8s.gcr.io/*
        policy:
          trust:
            enabled: false
          va:
            enabled: false
    EOF
    ```
    - `kubectl create -f argo-clusterimagepolicy.yaml`
- Install
  - `kubectl create ns argocd`
  - `kubectl apply -n argocd -f argocd-1.2.3-install.yaml`
- Ingress
```
cat | kubectl create -f - <<EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  labels:
    app: argocd-server
    release: argocd
  name: argocd-server-http
  namespace: argocd
spec:
  rules:
  - host: argocd.9.46.77.222.nip.io
    http:
      paths:
      - backend:
          serviceName: argocd-server
          servicePort: 80
EOF
```

## Login to ArgoCD Server
- Download Argo CD CLI
  - `wget https://github.com/argoproj/argo-cd/releases/download/v1.2.3/argocd-linux-amd64 -O /usr/local/bin/argocd`
  - `chmod +x /usr/local/bin/argocd`
- Login 
  - `ARGO_SERVER=$(kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.clusterIP}')`
  - `PASSWD=$(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2)`
  - argocd login $ARGO_SERVER --username admin --password $PASSWD
- Update initial password
  - `argocd account update-password --current-password $PASSWD`


# Install Argo Workflow
- reference doc: https://github.com/argoproj/argo/blob/master/demo.md#5-install-an-artifact-repository

## Install NFS external storage provider
- Refer to `Configure Storage` section in https://github.ibm.com/APM/AgentDeployment/wiki/Tekton-Pipeline-Env-Setup-Guidle#configure-storage
- Note: external storage provide must be install in `default` namespace

## Install Minio Artifact Repository
- Optional for kubeadm cluster
  ```
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: kube-system-binding-default
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
  subjects:
  - kind: ServiceAccount
    name: default
    namespace: kube-system
  ```

- Patch PSP for Artifact Repository
  - `kubectl patch psp -o yaml ibm-restricted-psp -p '{"spec": { "runAsUser": { "rule": "RunAsAny"}}}'`
-  Install an Artifact Repository
   ```
   helm install --tls stable/minio \
     --name argo-artifacts \
     --namespace argo \
     --set service.type=NodePort \
     --set defaultBucket.enabled=true \
     --set defaultBucket.name=my-bucket \
     --set persistence.enabled=true \
     --set fullnameOverride=argo-artifacts \
     --debug 2>&1 | tee minio-install.log
   ```
- Access to Minio UI
  - Check Minio service `kubectl get svc -n argo`
  - Find access key at https://github.com/argoproj/argo/blob/master/demo.md#5-install-an-artifact-repository
- Install and configure Minio CLI
  - Refer to https://docs.min.io/docs/minio-quickstart-guide.html  
## Install Argo Workflow

- Apply patch 
  - prepare patch 
    ```
    cat > argo-workflow-2.4.1.patch <<EOF
    --- argo-workflow-install-2.4.1.yaml.origin     2019-10-16 22:57:20.081560630 -0700
    +++ argo-workflow-install-2.4.1.yaml            2019-10-16 23:10:06.131402533 -0700
    @@ -228,7 +228,7 @@
     roleRef:
       apiGroup: rbac.authorization.k8s.io
       kind: ClusterRole
    -  name: argo-cluster-role
    +  name: ibm-anyuid-hostpath-clusterrole
     subjects:
     - kind: ServiceAccount
       name: argo
    @@ -251,6 +251,25 @@
     kind: ConfigMap
     metadata:
       name: workflow-controller-configmap
    +data:
    +  config: |
    +    ContainerRuntimeExecutor: kubelet
    +    artifactRepository:
    +      s3:
    +        bucket: my-bucket
    +        endpoint: argo-artifacts.argo:9000
    +        insecure: true
    +        # accessKeySecret and secretKeySecret are secret selectors.
    +        # It references the k8s secret named 'argo-artifacts'
    +        # which was created during the minio helm install. The keys,
    +        # 'accesskey' and 'secretkey', inside that secret are where the
    +        # actual minio credentials are stored.
    +        accessKeySecret:
    +          name: argo-artifacts
    +          key: accesskey
    +        secretKeySecret:
    +          name: argo-artifacts
    +          key: secretkey
    ---
    apiVersion: v1
    kind: Service    
    EOF
    ```
    - `patch argo-workflow-install-2.4.1.yaml argo-workflow-2.4.1.patch`
  - Install
    - `kubectl create -n argo -f argo-workflow-install-2.4.1.yaml`
  - Create `argo-ui-ingress`
    - replace `9.46.77.222` to your ICP proxy ip
    ```
    cat | kubectl create -n argo -f - <<EOF
    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      name: argo-ui-ingress
      namespace: argo
    spec:
      rules:
      - host: argo-ui.9.46.77.222.nip.io
        http:
          paths:
          - backend:
              serviceName: argo-ui
              servicePort: 80    
    EOF
    ```
    - Access to `Argo-UI` via http://argo-ui.9.46.77.222.nip.io 
    - Download `argo` CLI
      - Refer to https://github.com/argoproj/argo/blob/master/demo.md#1-download-argo

### Create rolebinding
- `kubectl create rolebinding argo-argo-admin --clusterrole=admin --serviceaccount=argo:argo`
- `kubectl create rolebinding argo-default-admin --clusterrole=admin --serviceaccount=argo:default`
      
# Notice

## Tips for Nodejs
- Resolve address registry.npmjs.org
  - known issue: https://github.com/npm/npm/issues/16661
  - add `"dns": [ "10.0.0.10", "8.8.8.8" ]` in `/etc/docker/daemon.json` and restart docker on EACH node
- Build Nodejs docker image in priviledged mone
  -  patch PSP
    - `kubectl patch psp -o yaml ibm-restricted-psp -p '{"spec": { "allowPrivilegeEscalation:": "true"}}'`
  - define kaniko template in privilege mode
    ```
    container:      
      image: 9.46.76.93:5000/kaniko-project/executor:latest
      securityContext:
        privileged: true 
    ```