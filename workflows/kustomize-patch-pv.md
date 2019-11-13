- Copy everything from previous example: kustomize-by-example.md
```
cd incident-expose
mkdir -p no-volume no-volume/base no-volume/no-volume
cp flatten.yaml patch.yaml deployment-api-patch.yaml kustomization.yaml no-volume/base/
cd no-volume/no-volume
kustomize create --resources ../base/

cat kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- ../base/
cd ..
```

- create `kustomization.yaml`
```
cat > no-volume/kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../base/
patchesJson6902:
- target:
    group: apps
    version: v1
    kind: StatefulSet
    name: winterfell-postgresql
  path: sts-deploy-patch.yaml

patchesStrategicMerge:
- pv-drop-patch.yaml
EOF
```

- create `sts-deploy-patch.yaml` to modify `StatefulSet` to `Deployment`
```
cat > no-volume/sts-deploy-patch.yaml <<EOF
- op: replace
  path: /apiVersion
  value: apps/v1
- op: replace
  path: /kind
  value: Deployment
- op: remove
  path: /spec/volumeClaimTemplates
- op: remove
  path: /spec/podManagementPolicy
- op: remove
  path: /spec/updateStrategy
- op: remove
  path: /spec/serviceName
- op: remove
  path: /spec/template/spec/containers/0/volumeMounts
- op: remove
  path: /spec/template/spec/initContainers/0/volumeMounts
EOF
```

- cretae `pv-drop-patch.yaml` to drop `PersistentVolume` and `StorageClass`
```
cat > no-volume/pv-drop-patch.yaml <<EOF
$patch: delete
apiVersion: v1
kind: PersistentVolume
metadata:
  annotations:
    pv.kubernetes.io/bound-by-controller: "yes"
  finalizers:
  - kubernetes.io/pv-protection
  labels:
    release: winterfell
  name: winterfell-local-storage-postgresql-pv
---
$patch: delete
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  labels:
    app: winterfell-postgresql
    release: winterfell
  name: winterfell-local-storage-postgresql
EOF
```

- Deploy application without `PersistentVolume`
```
  kustomize build no-volume/ | kubectl apply -f -
serviceaccount/winterfell-expose created
clusterrolebinding.rbac.authorization.k8s.io/winterfell-expose-role-binding created
configmap/winterfell-openresty-nginx created
configmap/winterfell-postgresql-init created
configmap/winterfell-postgrest-config created
service/winterfell-openresty created
service/winterfell-postgresql created
service/winterfell-postgrest created
deployment.apps/winterfell-openresty created
deployment.apps/winterfell-postgresql created
deployment.apps/winterfell-postgrest created
job.batch/init-db created
job.batch/test-db created
ingress.extensions/winterfell-openresty created
ingress.extensions/winterfell-postgrest created
```
- Delete application without `PersistentVolume`
```
  kustomize build no-volume/ | kubectl delete -f -
serviceaccount "winterfell-expose" deleted
clusterrolebinding.rbac.authorization.k8s.io "winterfell-expose-role-binding" deleted
configmap "winterfell-openresty-nginx" deleted
configmap "winterfell-postgresql-init" deleted
configmap "winterfell-postgrest-config" deleted
service "winterfell-openresty" deleted
service "winterfell-postgresql" deleted
service "winterfell-postgrest" deleted
deployment.apps "winterfell-openresty" deleted
deployment.apps "winterfell-postgresql" deleted
deployment.apps "winterfell-postgrest" deleted
job.batch "init-db" deleted
job.batch "test-db" deleted
ingress.extensions "winterfell-openresty" deleted
ingress.extensions "winterfell-postgrest" deleted
```