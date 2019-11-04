#!/bin/bash -xv

dest_host=$1

test -e ./$dest_host && rm -rf ./$dest_host
mkdir -p $dest_host; cd $dest_host

## copy from dest host, because helm version must be aligned
mkdir -p bin
scp $dest_host:/usr/local/bin/helm ./bin/helm
rm -f bin/jx  bin/pip bin/pip3 bin/pip3.6 bin/istioctl

## add argo utilities
cp    /usr/local/bin/argo \
      /usr/local/bin/argocd \
      /usr/local/bin/kustomize \
      /usr/local/bin/mc \
      /usr/local/bin/calicoctl \
      /usr/local/bin/kubectl \
      bin/
ls -l bin

scp -r $dest_host:/etc/cfc/conf .
scp -r $dest_host:/root/.kube .
scp -r $dest_host:/root/.helm .

rm -rf .helm/cache/archive/*

ls -a

cat >Dockerfile <<EOF
FROM alpine
RUN apk update && apk add curl git bash nginx jq openssh-client && mkdir -p /run/nginx/
ADD bin/ /usr/local/bin
ADD conf /etc/cfc/conf
ADD .kube /root/.kube
ADD .helm /root/.helm
EOF

docker build --network host -t 9.46.76.93:5000/default/alpine-utils-k8s:$dest_host .

docker run --rm -it 9.46.76.93:5000/default/alpine-utils-k8s:$dest_host kubectl get po

