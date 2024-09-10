# Step 5. Setup Vault for cert-manager vault issuer

# Create the policy in vault for the cert token usage. *** This policy needs to be cleansed.
cat ${WORKDIR}/policy/certPolicy.hcl | kubectl exec -i -n vault vault-0 -- vault policy write cert -

# Create token used by issuer for authentication from cert-manager - Cert Token
CERT_TOKEN=$(kubectl exec -it -n vault vault-0 -- vault token create -format=json -policy="cert" | jq -r ".auth.client_token")
echo $CERT_TOKEN

# Start a shell into vault-0
kubectl exec -it vault-0 -n vault --stdin=true --tty=true -- /bin/sh

# Enable kubernetes authentication
vault auth enable kubernetes

# Configure the location of the Kubernetes API
vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Create an Authentication Role
vault write auth/kubernetes/role/issuer \
    bound_service_account_names=issuer \
    bound_service_account_namespaces=vault \
    policies=cert \
    ttl=20m

exit

# Deploy cert-manager
/bin/bash ${WORKDIR}/scripts/deployCertManager.sh

# Create Issuer Service Account
kubectl create serviceaccount issuer

# Create an issuer secret config
cat >> ${WORKDIR}/kube/issuer-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: issuer-token-lmzpj
  annotations:
    kubernetes.io/service-account.name: issuer
type: kubernetes.io/service-account-token
EOF

# Create the issuer secret
kubectl apply -n vault -f ${WORKDIR}/kube/issuer-secret.yaml

# Create an env var to capture the secret name
ISSUER_SECRET_REF=$(kubectl get secrets -n vault --output=json | jq -r '.items[].metadata | select(.name|startswith("issuer-token-")).name')

# Define a vault issuer
cat > ${WORKDIR}/kube/vault-issuer.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: vault-issuer
  namespace: vault
spec:
  vault:
    server: http://vault.vault:8200
    path: pki_int/sign/example-dot-com
    auth:
      kubernetes:
        mountPath: /v1/auth/kubernetes
        role: issuer
        secretRef:
          name: $ISSUER_SECRET_REF
          key: token
EOF

# Create the vault issuer
kubectl apply -n vault --filename ${WORKDIR}/kube/vault-issuer.yaml

# Define a cert 
cat > ${WORKDIR}/kube/example-com-cert.yaml <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-com
  namespace: vault
spec:
  secretName: example-com-tls
  issuerRef:
    name: vault-issuer
  commonName: www.example.com
  dnsNames:
  - www.example.com
EOF

# Create the cert
kubectl apply -n vault --filename ${WORKDIR}/kube/example-com-cert.yaml

# View details of the cert
kubectl describe certificate.cert-manager -n vault example-com




