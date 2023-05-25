#!/bin/bash

export KUBECONFIG=/.kube.conf

APISERVER=$(kubectl config view --kubeconfig=./kube.conf -o jsonpath="{.clusters[?(@.name==\"$1\")].cluster.server}" | sed 's|https:\/\/||')
echo $APISERVER
export APISERVER=$(kubectl config view --kubeconfig=./kube.conf -o jsonpath='{.clusters[?(@.name=="$1")].cluster.server}' | sed 's|https:\/\/||')

echo $APISERVER
kubectl create cm kubernetes-services-endpoint --from-literal=KUBERNETES_SERVICE_HOST=$APISERVER --kubeconfig=./kube.conf -n tigera-operator || true

sleep 30s

kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}' --kubeconfig=./kube.conf || true

kubectl delete pod -n kube-system -l k8s-app=kube-dns --kubeconfig=./kube.conf || true

kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF", "hostPorts":null}}}' --kubeconfig=./kube.conf || true

