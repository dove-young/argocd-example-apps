# Workflow of Argo Workflow

## Install Argo Workflow env in macOS X - optional
- You might need local argo env if you would use `WorkflowTemplate` in your workflows
- Setup K8S mini cluster on macOS X 
    - Install Docker Desktop from https://docs.docker.com/docker-for-mac/install/
      - Check `Enable Kubernetes` in `Preference`
    - Install latest `argo` `workflow-controller` from https://github.com/argoproj/argo/releases
    - You might need to re-install `argo` `workflow-controller` after Docker Desktop upgrade K8S   
## Install `argo` client
- Install `argo` client from https://github.com/argoproj/argo/releases
    - for example: Download `argo-darwin-amd64` and rename it to `argo`

## Compose an Argo workflow
- Compose a workflow definition
  - for example: https://github.com/argoproj/argo/blob/master/examples/hello-world.yaml
    ```
    apiVersion: argoproj.io/v1alpha1
    kind: Workflow
    metadata:
      generateName: hello-world-
    spec:
      entrypoint: whalesay
      templates:
      - name: whalesay
        container:
          image: docker/whalesay:latest
          command: [cowsay]
          args: ["hello world"]
    ```
- Validate workflow syntax
  - `argo lint hello-world.yaml`
    - You might need to fix workflow if anything fails at `argo lint`
- Submit workflow
  - `argo submit hello-world.yaml`
  - for example:
    ```
    Name:                hello-world-mcfr5
    Namespace:           argo
    ServiceAccount:      default
    Status:              Pending
    Created:             Fri Oct 25 11:46:51 +0800 (now)
    ```
- Check workflow status
  - `argo get hello-world-mcfr5`
  - for example:
    ```
    Name:                hello-world-mcfr5
    Namespace:           argo
    ServiceAccount:      default
    Status:              Succeeded
    Created:             Fri Oct 25 11:46:51 +0800 (1 minute ago)
    Started:             Fri Oct 25 11:46:51 +0800 (1 minute ago)
    Finished:            Fri Oct 25 11:47:26 +0800 (46 seconds ago)
    Duration:            35 seconds
    
    STEP                             PODNAME            DURATION  MESSAGE
     ✔ hello-world-mcfr5 (whalesay)  hello-world-mcfr5  34s
    ```
- Check workflow logs
  - `argo logs -f -w hello-world-mcfr5`
  - for example:
    ```
    hello-world-mcfr5:	 _____________
    hello-world-mcfr5:	< hello world >
    hello-world-mcfr5:	 -------------
    hello-world-mcfr5:	    \
    hello-world-mcfr5:	     \
    hello-world-mcfr5:	      \
    hello-world-mcfr5:	                    ##        .
    hello-world-mcfr5:	              ## ## ##       ==
    hello-world-mcfr5:	           ## ## ## ##      ===
    hello-world-mcfr5:	       /""""""""""""""""___/ ===
    hello-world-mcfr5:	  ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
    hello-world-mcfr5:	       \______ o          __/
    hello-world-mcfr5:	        \    \        __/
    hello-world-mcfr5:	          \____\______/
    ```
- Check workflow logs from K8S 
  - `kubectl logs hello-world-mcfr5 -c wait` - find pod name from `argo get` result
  - for example:
    ```
    time="2019-10-25T03:47:10Z" level=info msg="Creating a docker executor"
    time="2019-10-25T03:47:10Z" level=info msg="Executor (version: v2.4.2, build_date:  2019-10-21T18:39:09Z) initialized (pod: argo/hello-world-mcfr5) with template:\n {\"name\":\"whalesay\",\"arguments\":{},\"inputs\":{},\"outputs\":{},\"metadata\":{},    \"container\":{\"name\":\"\",\"image\":\"docker/whalesay:latest\",\"command\":[\"cowsay\"], \"args\":[\"hello world\"],\"resources\":{}}}"
    time="2019-10-25T03:47:10Z" level=info msg="Waiting on main container"
    time="2019-10-25T03:47:25Z" level=info msg="main container started with container ID:   53c6e9952d4bd79402b7bc69e496e6507d04fa917181ea47e4b3501687117b18"
    time="2019-10-25T03:47:25Z" level=info msg="Starting annotations monitor"
    time="2019-10-25T03:47:25Z" level=info msg="docker wait     53c6e9952d4bd79402b7bc69e496e6507d04fa917181ea47e4b3501687117b18"
    time="2019-10-25T03:47:25Z" level=info msg="Starting deadline monitor"
    time="2019-10-25T03:47:25Z" level=info msg="Main container completed"
    time="2019-10-25T03:47:25Z" level=info msg="No output parameters"
    time="2019-10-25T03:47:25Z" level=info msg="No output artifacts"
    time="2019-10-25T03:47:25Z" level=info msg="No Script output reference in workflow. Capturing   script output ignored"
    time="2019-10-25T03:47:25Z" level=info msg="Killing sidecars"
    time="2019-10-25T03:47:25Z" level=info msg="Annotations monitor stopped"
    time="2019-10-25T03:47:25Z" level=info msg="Alloc=4836 TotalAlloc=11406 Sys=70334 NumGC=4 Goroutines=9"
    ```
  - `kubectl logs hello-world-mcfr5 -c main`
  - for example:
    ```
     _____________
    < hello world >
     -------------
        \
         \
          \
                        ##        .
                  ## ## ##       ==
               ## ## ## ##      ===
           /""""""""""""""""___/ ===
      ~~~ {~~ ~~~~ ~~~ ~~~~ ~~ ~ /  ===- ~~~
           \______ o          __/
            \    \        __/
              \____\______/
    ```
### Submit Argo workfrow to Pipeline environment
- Configure K8S authentication 
    - Option 1: 
        - Copy configuration from `~/.kube/config` in pipeline env to local env, includes
            - `cluster`
            - `context`
            - `user`
        - Submit workflow to pipeline env with `--cluster` and `--context` parameter, for example
          ```
          argo submit --cluster kubernetes --context argo-k8s hello-world.yaml
          Name:                hello-world-2kgmp
          Namespace:           argo
          ServiceAccount:      default
          Status:              Pending
          Created:             Fri Oct 25 12:03:06 +0800 (1 second ago)
          ```    
    - Option 2:
        - Copy configuration from `~/.kube/config` in pipeline env to a separate file
            - for example `~/.kube/server-config`
        - Submit workflow to pipeline env with `--kubeconfig` and `--context` parameter, for example
          ```
          argo submit --kubeconfig ~/.kube/server-config --context argo hello-world.yaml
          Name:                hello-world-fjttf
          Namespace:           argo
          ServiceAccount:      default
          Status:              Pending
          Created:             Fri Oct 25 12:10:48 +0800 (now)
          ```
## When you are using `WorkflowTemplate` in your workflow
- You would need to create `WorkflowTemplate` in K8S cluster before lint your workflow
    - `argo template create your-workflowtemplate.yaml`
    - `argo lint your-workflow.yaml`                    