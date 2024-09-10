#!/bin/bash

export SERVICE_NAME=vault-internal
export NAMESPACE=vault
export SECRET_NAME=vault-tls
export WORKDIR=/media/tim/ExtraDrive1/Projects/learn-hashicorp-vault/vault-tls
export CSR_NAME=vault.svc
export VAULT_HELM_RELEASE_NAME="vault"
export K8S_CLUSTER_NAME="cluster.local"

#create key for kubernetes to sign
openssl genrsa -out ${WORKDIR}/crypto/vault.key 2048

#Create the csr from csr.conf
openssl req -new -key ${WORKDIR}/crypto/vault.key -out ${WORKDIR}/csr/vault.csr -config ${WORKDIR}/csr/vault-csr.conf

#Send the csr to kubernetes using csr.yaml 
#*** Note - The cat below is used for substituting the base64 csr into 
# the csr.yaml file. This must be done prior to invoking the kubectl create.
cat > ${WORKDIR}/kube/csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: vault.svc
spec:
  signerName: kubernetes.io/kubelet-serving
  expirationSeconds: 8640000
  request: $(cat ${WORKDIR}/csr/vault.csr|base64|tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

kubectl create -f ${WORKDIR}/kube/csr.yaml

#Approve csr
kubectl certificate approve ${CSR_NAME}

#Verify it was created
kubectl get csr ${CSR_NAME}

#Retrieve newly created cert
kubectl get csr vault.svc -o jsonpath='{.status.certificate}' | openssl base64 -d -A -out ${WORKDIR}/crypto/vault.crt

#Retrieve kubernetes CA cert
kubectl get cm kube-root-ca.crt -o jsonpath="{['data']['ca\.crt']}" > $WORKDIR/crypto/vault.ca

#Create namespace
echo "Create vault Namespace"
kubectl create namespace ${NAMESPACE}

#Store the key into a secret
echo "Create secret and store vault and vault ca keys"
kubectl create secret generic ${SECRET_NAME} \
    --namespace ${NAMESPACE} \
    --from-file=vault.key=${WORKDIR}/crypto/vault.key \
    --from-file=vault.crt=${WORKDIR}/crypto/vault.crt \
    --from-file=vault.ca=${WORKDIR}/crypto/vault.ca

#########################################################################
#Deploy vault
echo "Deploy vault via helm chart"
helm install vault hashicorp/vault -n vault -f ${WORKDIR}/kube/vault-tls.yaml

# The initial deployment of vault is now complete. It takes approx 1 minute for the
# deployment to be ready before you can proceed with the steps in 
# Step-3-deployVaultSetup.sh

        
