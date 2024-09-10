#!/bin/bash

#Deploying cert-manager components
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.14.5/cert-manager.yaml

# Waiting for cert-manager components to be ready
echo "Waiting for cert-manager components to be ready."
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector
kubectl -n cert-manager rollout status deploy/cert-manager-webhook

