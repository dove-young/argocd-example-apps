#!/bin/bash -xv
#signal_dc_key=$1
repo=${2:-argocd-example-apps}
str=$1


    curl  \
        -H 'Content-Type: application/json' \
        -H 'Accept: application/vnd.github.symmetra-preview+json' \
        -H "Authorization: token $github_token" \
        "https://api.github.com/repos/dove-young/${repo}/${str}" 


