# kind-oidc

This document explains how you can set up OpenID Connect (OIDC) authentication on a Kubernetes cluster using Kind.

This is for Kubernetes tool developers.
You can test if your tool and OIDC provider works with a real cluster.


## Overview

You can set up OIDC authentication by the following steps:

1. Deploy an OIDC provider outside of the cluster.
1. Create a cluster with the extra arguments for OIDC.
1. Set up kubectl.

You need to consider the following constraints:

- The issuer URL must be HTTPS. A TLS certificate is required.
- You cannot deploy an OIDC provider in the cluster,
  because the API server cannot access any pod or service.
- The API server and kubectl access an OIDC provider via the same URL.


## Examples

### Okta

It is easy to use public identity providers such as Google, Auth0 and Okta.
Here is an example using Okta.

```sh
export KUBECONFIG=output/kubeconfig.yaml

# create a cluster
kind create cluster --config cluster-okta.yaml

# bind a cluster role to your user
kubectl create clusterrolebinding oidc-admin --clusterrole=cluster-admin --user=admin@example.com

# set up the kubeconfig
kubectl config set-credentials oidc --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=https://dev-REDUCTED.okta.com \
  --exec-arg=--oidc-client-id=REDUCTED \
  --exec-arg=--oidc-extra-scope=email

# make sure you can access the cluster
kubectl --user=oidc cluster-info

# clean up
kind delete cluster
```

### Dex (local)

You can set up the authentication using [Dex](https://github.com/dexidp/dex) on Docker on your machine.
This is useful for automated tests on CI.

```sh
export KUBECONFIG=output/kubeconfig.yaml

# generate CA and TLS server certificates
./generate-dex-tls.sh

# run a container of Dex
docker create --name dex-server -p 10443:10443 quay.io/dexidp/dex:v2.21.0 serve /dex.yaml
docker cp output/dex-server.crt dex-server:/
docker cp output/dex-server.key dex-server:/
docker cp dex.yaml dex-server:/
docker start dex-server

# create a cluster
kind create cluster --config cluster-dex.yaml

# set up the hosts so that the API server can access Dex
docker inspect -f '{{.NetworkSettings.IPAddress}}' dex-server | sed -e 's,$, dex-server,' | \
  kubectl -n kube-system exec -i kube-apiserver-kind-control-plane -- tee -a /etc/hosts

# set up the hosts so that kubectl can access Dex
echo '127.0.0.1 dex-server' | sudo tee -a /etc/hosts

# bind a cluster role to your user
kubectl create clusterrolebinding oidc-admin --clusterrole=cluster-admin --user=admin@example.com

# set up the kubeconfig
kubectl config set-credentials oidc --exec-api-version=client.authentication.k8s.io/v1beta1 \
  --exec-command=kubectl \
  --exec-arg=oidc-login \
  --exec-arg=get-token \
  --exec-arg=--oidc-issuer-url=https://dex-server:10443/dex \
  --exec-arg=--oidc-client-id=YOUR_CLIENT_ID \
  --exec-arg=--oidc-client-secret=YOUR_CLIENT_SECRET \
  --exec-arg=--oidc-extra-scope=email \
  --exec-arg=--certificate-authority=$PWD/output/dex-ca.crt

# make sure you can access the cluster
kubectl --user=oidc cluster-info

# clean up
kind delete cluster
docker stop dex-server
docker rm dex-server
```
