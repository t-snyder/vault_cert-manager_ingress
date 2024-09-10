# **************** Note - Below is a prerequisite
minikube addons enable ingress-nginx 

#print out the Admin token
echo $ADMIN_TOKEN

# Log into the Vault UI
https://127.0.0.1:8200/ui

# Login with the ADMIN_TOKEN above which has
# been displayed above in the terminal via the echo command. 
#
# *** Note if login fails due to authentication error and you have logged into Vault UI
# before, follow the instructions below to remove the old token. 
# 
# go to the Person icon and select Revoke token, the select Logout. This will
# give you a new authentication screen to enter the new token.
#
Step 1. Generate a new Intermediate CA
#    Select Secrets Engines on left and then Enable new engine
#    Select PKI Certificates
#      Path - pki_int_foo
#      Max lease TTL - 43800 hours
#      Select Enable Engine 
#    The pki_int Overview screen will complain that the pki is not configured.    
#    Select Configure PKI
#    Select Generate Intermediate CSR
#      Type - internal
#      Common Name - foo.com Intermediate Authority
#      Select Generate
#    On View Generated CSR 
#      Select the copy icon next to the CSR Pem and copy to clipboard.
#      Save the pem file as pki_int_foo.csr ($WORKDIR/csr a good place)
#
#    Now we need to sign the CSR with the Root CA.
#    Return to Dashboard - select pki Secrets engine -> Select Issuers tab
#    Select root-2024 issuer
#    Select Sign Intermediate tab
#      Paste Pem CSR into CSR field
#      Common name -foo.com
#      Format      - pem_bundle
#      Select Save to sign
#
#    Copy Certificate via copy icon. Save to int_foo_cert.pem
#    Copy and save Issuing CA and CA Chain
#
#    Go to Dashboard -> select pki_int_foo from Secrets engines
#    Select Configure PKI
#    Select Import a CA
#    PEM Bundle - Browse to and select the int_foo_cert.pem file you saved.
#    Select Import Issuer
#    Select Done
#
# Step 3. Create a Role
#    Using a terminal obtain the issuer id:
#      kubectl exec -it -n vault vault-0 -- vault read -field=default pki_int_foo/config/issuers
#    Copy the id output
#  
#    From Dashboard -> pki_int_foo -> Roles (View roles) -> Create Role
#    On Create a PKI Role 
#     Role name - foo-dot-com
#     Toggle off the Use default Issuer
#       Select the issuer with the id output in the terminal step above
#     Under Not valid after enter TTL - 43800 hours
#     Expand Domain Handling
#       Turn on Allow subdomains
#       In Allowed domains enter - foo.com
#       Select Create
#
# Step 4. Request Certificates
#    From Dashboard -> select pki_int_foo -> Roles (View Roles) -> foo-dot-com
#    Select the Generate certificate tab
#       Common name - papaya.foo.com
#       Under Not Valid after - set TTL 24 hours
#       Select Generate

# Create Papaya issuer role and binding
WORKDIR=/media/tim/ExtraDrive1/Projects/learn-hashicorp-vault/vault-tls
kubectl create namespace papaya

kubectl apply -n papaya -f $WORKDIR/kube/papaya-issuer-role.yaml

# Now create the vault role
kubectl exec -it -n vault vault-0 -- /bin/sh

vault write auth/kubernetes/role/vault-issuer-role \
    bound_service_account_names=vault-papaya-issuer \
    bound_service_account_namespaces=papaya \
    audience="vault://papaya/vault-papaya-issuer" \
    policies=default \
    ttl=1m

exit
   
# Deploy papaya kube artifacts
kubectl apply -f $WORKDIR/kube/papaya-pvc.yaml -n papaya

kubectl apply -f $WORKDIR/kube/papaya.yaml -n papaya

# Test
ipAddr=$(minikube ip)
echo "Minikube ip = $ipAddr"
sudo -- sh -c 'echo "\n'"$ipAddr"' papaya.foo.com\n" >> /etc/hosts'

#curl -kL https://papaya.foo.com/papaya
# Successful response = Pekko-http says that Papaya is a sweet fruit

