#Prerequsites

- According to the `values.yaml` file, preparing following prerequsites
  - PostgreSQL database storage
    - Create data directory on favorited ICP node and have directory been owned by an non-privilege user
    - for example:
    ```
    mkdir -p /k8s/data/postgres
    useradd -u 1000  dbuser
    chown 1000 /k8s/data/postgres
    ```
  - Kubernetes proxy host name
  - PostgreSQL database password
  - Postgrest secret and token
  - Postgrest ingress path
 - Modify `values.yaml` to alaign to above 

# Deploy

- Install from helm chart into ICP
  - replace `release` to your favorite release name
```
helm install --name release  --tls --debug incident-expose
```

# ICAM Outgoing 
- Define webhook into ICAM
  - replace `<full-qualify-proxy-hostname>` to your ICP proxy hostname
  - replace `<openresty-ingress-path>` to your openresty ingress path
  - replace `<jwt-token>` to your jwt token created from jwt secret
```
https://<full-qualify-proxy-hostname>/<openresty-ingress-path>?token=<jwt-token>
```

# Delete
- Delete helm release from ICP
  - replace `release` to your favorite release name
```
helm del --purge release --tls
```

- Delete PV
  - replace `release` to your favorite release name
```
kubectl patch  pv release-local-storage-postgresql-pv -p '{"metadata":{"finalizers":null}}'
kubectl delete pvc data-release-postgresql-0
```