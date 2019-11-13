### K8S API Version migration
- Reference: https://github.com/kubernetes-sigs/kustomize/blob/master/examples/jsonpatch.md
- Problem:
  - `Error: validation failed: unable to recognize "": no matches for kind "Deployment" in version "extensions/v1beta1"`
- Reason:
  - K8S v1.16 has moved kind `Deployment` from `extensions/v1beta1` to `apps/v1`
- Reproduce:  
    - Clone example code
        - `git clone --depth 1 git@github.ibm.com:yangboh/argocd-example-apps.git`
        - `cd argocd-example-apps`
    - Try install `incident-expose` helm chart
      ```
      helm install --name test --debug incident-expose/
      [debug] Created tunnel using local port: '43097'
    
      [debug] SERVER: "127.0.0.1:43097"
    
      [debug] Original chart version: ""
      [debug] CHART PATH: /root/argocd-example-apps/incident-expose
    
      Error: validation failed: unable to recognize "": no matches for kind "Deployment" in version "extensions/v1beta1"
      ```
 
 - Resolve via `kustomize` patch
    - Flatten helm chart using `helm template`
        - `helm template incident-expose --name=winterfell > incident-expose/flatten.yaml`
    - Create a `kustomization.yaml` file
      ```
      [root@agentavtone-worker3 argocd-example-apps]# cd incident-expose/
      [root@agentavtone-worker3 incident-expose]# kustomize create
      [root@agentavtone-worker3 incident-expose]# ls -l
      total 20
      -rw-r--r-- 1 root root  111 Nov 12 22:31 Chart.yaml
      -rw-r--r-- 1 root root   64 Nov 12 22:40 kustomization.yaml
      -rw-r--r-- 1 root root 1368 Nov 12 22:31 README.md
      drwxr-xr-x 3 root root 4096 Nov 12 22:31 templates
      -rw-r--r-- 1 root root  505 Nov 12 22:31 values.yaml
      [root@agentavtone-worker3 incident-expose]# cat kustomization.yaml
      apiVersion: kustomize.config.k8s.io/v1beta1
      kind: Kustomization
      [root@agentavtone-worker3 incident-expose]#
      ```
    - Define kustomization rules
      ```
      cat >> kustomization.yaml <<EOF
      resources:
      - flatten.yaml
      patchesJson6902:
      - target:
          group: extensions
          version: v1beta1
          kind: Deployment
          name: winterfell-openresty
        path: deployment-api-patch.yaml
      - target:
          group: extensions
          version: v1beta1
          kind: Deployment
          name: winterfell-postgrest
        path: deployment-api-patch.yaml
      EOF
      ```
    - Define `deployment-api-patch.yaml` patch
      ```
      cat > deployment-api-patch.yaml <<EOF
      - op: replace
        path: /apiVersion
        value: apps/v1
      EOF
      ```
    - Verify patch works
      - before patch
        ```
        grep -b2 Deployment flatten.yaml
        17131-# Source: incident-expose/templates/openresty-deploy.yaml
        17189-apiVersion: extensions/v1beta1
        17220:kind: Deployment
        17237-metadata:
        17247-  labels:
        --
        18857-# Source: incident-expose/templates/postgrest-deploy.yaml
        18915-apiVersion: extensions/v1beta1
        18946:kind: Deployment
        18963-metadata:
        18973-  labels:
        ```
      - after patch
        ```
        kustomize build . | grep -b2 Deployment
        14180----
        14184-apiVersion: apps/v1
        14204:kind: Deployment
        14221-metadata:
        14231-  labels:
        --
        15834----
        15838-apiVersion: apps/v1
        15858:kind: Deployment
        15875-metadata:
        15885-  labels:
        ```
- Deploy patched application to K8S cluster
  - using `kubectl` before `v1.16.2`
    - `kustomize build . | kubectl apply -f -`
  - using `kubectl` `v1.16.2`
    - `kubectl apply -k .`  or
    - `kubectl apply --kustomize .`
  - you can also check it with `--dry-run`
    - `kubectl apply --kustomize . --dry-run`
  - for example:
    ```
    kubectl apply -k .
    storageclass.storage.k8s.io/winterfell-local-storage-postgresql created
    serviceaccount/winterfell-expose created
    clusterrolebinding.rbac.authorization.k8s.io/winterfell-expose-role-binding created
    configmap/winterfell-openresty-nginx created
    configmap/winterfell-postgresql-init created
    configmap/winterfell-postgrest-config created
    service/winterfell-openresty created
    service/winterfell-postgresql created
    service/winterfell-postgrest created
    deployment.apps/winterfell-openresty created
    deployment.apps/winterfell-postgrest created
    statefulset.apps/winterfell-postgresql created
    job.batch/init-db created
    job.batch/test-db created
    ingress.extensions/winterfell-openresty created
    ingress.extensions/winterfell-postgrest created
    persistentvolume/winterfell-local-storage-postgresql-pv created

    kubectl get po
    NAME                                    READY   STATUS      RESTARTS   AGE
    init-db-jm52l                           0/1     Completed   0          2m29s
    nfs-provisioner-0                       1/1     Running     5          13d
    test-db-wvwfg                           0/1     Completed   0          2m29s
    winterfell-openresty-558476d759-t6qcs   1/1     Running     0          2m29s
    winterfell-postgresql-0                 1/1     Running     0          10s
    winterfell-postgrest-658c9dc886-snp65   1/1     Running     0          2m29s
    ```
- Remove resource from K8S
  - Patch pv removing finalizers
    ```
    kubectl patch pv winterfell-local-storage-postgresql-pv --type="json" \
            -p='[{"op": "replace", "path": "/metadata/finalizers", "value": [] }]'
    ```
  - Remove everything
    ```
    kubectl delete -k .
    storageclass.storage.k8s.io "winterfell-local-storage-postgresql" deleted
    serviceaccount "winterfell-expose" deleted
    clusterrolebinding.rbac.authorization.k8s.io "winterfell-expose-role-binding" deleted
    configmap "winterfell-openresty-nginx" deleted
    configmap "winterfell-postgresql-init" deleted
    configmap "winterfell-postgrest-config" deleted
    service "winterfell-openresty" deleted
    service "winterfell-postgresql" deleted
    service "winterfell-postgrest" deleted
    deployment.apps "winterfell-openresty" deleted
    deployment.apps "winterfell-postgrest" deleted
    statefulset.apps "winterfell-postgresql" deleted
    job.batch "init-db" deleted
    job.batch "test-db" deleted
    ingress.extensions "winterfell-openresty" deleted
    ingress.extensions "winterfell-postgrest" deleted
    persistentvolume "winterfell-local-storage-postgresql-pv" deleted
    ```    