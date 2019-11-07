## Install Argo-Events
- Reference: https://argoproj.github.io/argo-events/installation/
- `helm repo add argo https://argoproj.github.io/argo-helm`
- `kubectl create ns argo-events`
- `helm install argo/argo-events --version 0.5.2 --namespace argo-events --name argo-events` 
- create `clusterrolebinding`
  ```
  kubectl create clusterrolebinding argo-events-default-admin  \
          --serviceaccount argo-events:default \
          --namespace argo-events \
          --clusterrole=cluster-admin
  ```          

## Define Github events hook for IBM Github
- Create Github access secret
  - generate Github personal access tocken
    - https://github.ibm.com/settings/tokens
  - generate secret string
    - `ruby -rsecurerandom -e 'puts SecureRandom.hex(20)'`
  - create github access secret
    ```
    kubectl create secret generic github-access \
    --from-literal=token=<your github personal access token> \
    --from-literal=secret=<your secret string> \
    --namespace argo-events
    ```      
- Event Source
  - fetch event source
    ```
    wget https://raw.githubusercontent.com/argoproj/argo-events/master/examples/event-sources/github.yaml \
         -O github-event-source.cm-ee.yaml
    ```
  - `sed -i -e '/example-with-secure-connection/, $d' github-event-source.cm-ee.yaml`
  - prepare patch file `github-event-source.patch`
    - *replace `9.46.75.116` to your node ip adderss*
    - *replace `owner: "yangboh"` to your github account*
    - *replace `repository: "argocd-example-apps"` to your github repository*
    ```
    cat > github-event-source.patch <<EOF
    --- github-event-source.cm-ee.yaml      2019-11-06 18:51:32.961766971 -0800
    +++ github-event-source.cm-ee.yaml      2019-11-06 18:46:26.621465854 -0800
    @@ -12,19 +12,22 @@
     data:
       example: |-
         # owner of the repo
    -    owner: "argoproj"
    +    owner: "yangboh"
         # repository name
    -    repository: "argo-events"
    +    repository: "argocd-example-apps"
         # Github will send events to following port and endpoint
    +    id: 5415689
    +    githubBaseURL: "https://github.ibm.com/api/v3/"
    +    githubUploadURL: "https://github.ibm.com/api/v3/upload"
         hook:
          # endpoint to listen to events on
          endpoint: "/push"
          # port to run internal HTTP server on
    -     port: "12000"
    +     port: "9332"
          # url the gateway will use to register at Github.
          # This url must be reachable from outside the cluster.
          # The gateway pod is backed by the service defined in the gateway spec. So get the URL for that service Github can reach to.
    -     url: "http://myfakeurl.fake"
    +     url: "http://9.46.75.116:12000"
         # type of events to listen to.
         # following listens to everything, hence *
         # You can find more info on https://developer.github.com/v3/activity/events/types/
    EOF
    ```
    - apply patch
      - `patch github-event-source.cm-ee.yaml github-event-source.patch`
    - create github event source
      - `kubectl create -n argo-events -f github-event-source.cm-ee.yaml`
- Github Gateway
  - fetch `github.yaml`  
    ```
    wget https://raw.githubusercontent.com/argoproj/argo-events/master/examples/gateways/github.yaml \
         -O github-gateway.yaml
    ```
  - prepare patch file `github-gateway.patch`
    - **replace `externalIPs` to your node ip address**
    ```
    cat > github-gateway.patch <<EOF
    --- github-gateway.yaml 2019-11-06 18:34:37.498132205 -0800
    +++ github-gateway.yaml 2019-11-06  00:42:22.734601999 -0800
    @@ -24,11 +24,17 @@
         spec:
           containers:
             - name: "gateway-client"
    -          image: "argoproj/gateway-client"
    +          env:
    +          - name: DEBUG_LOG
    +            value: "true"
    +          image: "argoproj/gateway-client:v0.10"
               imagePullPolicy: "Always"
               command: ["/bin/gateway-client"]
             - name: "github-events"
    -          image: "argoproj/github-gateway"
    +          env:
    +          - name: DEBUG_LOG
    +            value: "true"
    +          image: "argoproj/github-gateway:v0.10"
               imagePullPolicy: "Always"
               command: ["/bin/github-gateway"]
           serviceAccountName: "argo-events-sa"
    @@ -38,10 +44,12 @@
         spec:
           selector:
             gateway-name: "github-gateway"
    +      externalIPs:
    +      - 9.46.75.116
           ports:
             - port: 12000
    -          targetPort: 12000
    -      type: LoadBalancer
    +          targetPort: 9332
    +      type: ClusterIP
       watchers:
         sensors:
           - name: "github-sensor"
    EOF
    ```
    - apply patch
      - `patch github-gateway.yaml github-gateway.patch` 
    - create github gateway
      - `kubectl create -n argo-events -f github-gateway.yaml`         
- Check Github webhooks
  - go to `settings -> hooks` in your github repository
    - for example: https://github.ibm.com/yangboh/argocd-example-apps/settings/hooks/  
  - check `Recent Deliveries`, find your `hook_id`
- Edit  `github-event-source` `ConfigMap`, replace `id` to your correct `hook_id`
  - `kubectl edit -o yaml cm github-event-source`
- Try your webhook by click `Redeliver` button on the webhook page