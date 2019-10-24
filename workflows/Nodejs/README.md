

## Submit workflow
- `argo submit avt-workflow.yaml`
- `argo list`
- `argo get <workflow-name>`
- `argo logs -f -w <workflow-name>`

## Kustomize Deployment

### Kustomize `nodejsapp-feature-controller.yml`
- `cd kustmization`
- `kustomize build overlays/staging/`

### Kustomize `avt-workflow.yaml`
- `cd kustmization`
- `kustomize build argo/`
