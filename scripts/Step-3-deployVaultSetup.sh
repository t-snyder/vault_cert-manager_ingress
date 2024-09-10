#Steps from Install to minikube with TLS enabled
#https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls


#Vault internal setup commands - join, unseal. create kv-v2

# Verify deployment - Note the vault pods will show READY = 0/1 until the unsealing and 
# joining has been performed.
kubectl -n vault get pods

# Note - proceed when vault-0 is up and ready
#Initialize vault-0 with 1 keyshare and 1 key threshhold
echo "Initialize vault-0 with 1 keyshare and 1 key threshhold"
kubectl exec -it -n vault vault-0 -- vault operator init \
    -key-shares=1 \
    -key-threshold=1 \
    -format=json > ${WORKDIR}/crypto/cluster-keys.json   

#Display the unseal key
jq -r ".unseal_keys_b64[]" ${WORKDIR}/crypto/cluster-keys.json

#Create env variable for the key
VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" ${WORKDIR}/crypto/cluster-keys.json) 
 
#Unseal vault-0
echo "Unseal vault-0"
kubectl exec -n vault vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY 

#Join Vault-1
kubectl exec -it -n vault vault-1 -- /bin/sh
vault operator raft join -address=https://vault-1.vault-internal:8200 -leader-ca-cert="$(cat /vault/userconfig/vault-tls/vault.ca)" -leader-client-cert="$(cat /vault/userconfig/vault-tls/vault.crt)" -leader-client-key="$(cat /vault/userconfig/vault-tls/vault.key)" https://vault-0.vault-internal:8200
exit

#Join vault-2
kubectl exec -it -n vault vault-2 -- /bin/sh
vault operator raft join -address=https://vault-2.vault-internal:8200 -leader-ca-cert="$(cat /vault/userconfig/vault-tls/vault.ca)" -leader-client-cert="$(cat /vault/userconfig/vault-tls/vault.crt)" -leader-client-key="$(cat /vault/userconfig/vault-tls/vault.key)" https://vault-0.vault-internal:8200
exit

#Unseal vault-1
kubectl exec -it -n vault vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY

#unseal vault-2
kubectl exec -it -n vault vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY

#Display root token found in cluster-keys.json
jq -r ".root_token" ${WORKDIR}/crypto/cluster-keys.json

export CLUSTER_ROOT_TOKEN=$(cat ${WORKDIR}/crypto/cluster-keys.json | jq -r ".root_token")

#Start a shell into vault-0 and login 
kubectl exec -n vault vault-0 -- vault login $CLUSTER_ROOT_TOKEN

#List the raft peers
kubectl exec -n vault vault-0 -- vault operator raft list-peers

#Review HA status
kubectl exec -n vault vault-0 -- vault status

#Start a shell into vault-0
kubectl exec --stdin=true --tty=true -n vault vault-0 -- /bin/sh

#Enable instance of kv-v2 secrets engine
vault secrets enable -path=secret kv-v2

#Create secrets path - username and password from 
vault kv put secret/test/apitest username="apiuser" password="supersecret"

#verify secret defi
vault kv get secret/test/apitest

exit

#Confirm Vault service config
kubectl -n vault get service vault

#Go to a different terminal and set port forward
kubectl -n vault port-forward service/vault 8200:8200

#Back to original terminal - Test
curl --cacert $WORKDIR/crypto/vault.ca \
   --header "X-Vault-Token: $CLUSTER_ROOT_TOKEN" \
   https://127.0.0.1:8200/v1/secret/data/test/apitest | jq .data.data

# This step of vault setup as a secrets engine is complete. Go to Step 4.

