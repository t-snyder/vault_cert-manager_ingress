# These steps incorporate the steps necessary to set up Vault as a Root and Intermediate
# CA, and finally generate a Certificate
#
# There are 2 versions within this document. The first uses the Vault UI. The second 
# uses kubectl and vault cli commands. 
#
# ********** Note - All the steps in the first option using kubectl and vault cli work
# except the final step generating Certificates. However
# the steps within the UI do successfully work.
#
# Also if the UI is used to generate the Root and Intermediate Certs and Roles then
# the final step of generating Certificates work with both the kubectl / vault cli as
# well as curl.

echo "Create Admin Policy"
cat ${WORKDIR}/policy/adminPolicy.hcl | kubectl exec -i -n vault vault-0 -- vault policy write admin -

#export VAULT_ADDR=https://vault-0.vault-internal:8200

kubectl exec -it -n vault vault-0 -- /bin/sh

#List policies
vault policy list

#Read admin policy
vault policy read admin

#exitexit Vault-0 shell
exit 

#Create an admin token
ADMIN_TOKEN=$(kubectl exec -it -n vault vault-0 -- vault token create -format=json -policy="admin" | jq -r ".auth.client_token")

#print out token
echo $ADMIN_TOKEN

#Retrieve token capabilities
kubectl exec -it -n vault vault-0 -- vault token capabilities $ADMIN_TOKEN sys/auth/approle

# Below is the vault ui url for logging into vault. Using the UI is the only option I
# found that would successfully complete the necessary tasks. Within the kubectl 
# command steps below I have indicated where I started receiving errors. All of the 
# commands are successful, except when trying to generate a new certificate at the final 
# step.
#
# Also the browser is going to complain about the self signed cert for the UI. Just
# accept.
#
# https://127.0.0.1:8200/ui
#
# If using the UI from this point on then login with the ADMIN_TOKEN above which has
# been displayed in the terminal via the echo command. 
#
# *** Note if login fails due to authentication error and you have logged into Vault UI
# before, follow the instructtions below to remove the old token. 
# receive an authentication error when entering
# If so then go to the Person icon and select Revoke token, the select Logout. This will
# give you a screen to enter the new token.
# 
# Step 1. Generate Root CA
# At the Dashboard
#    Select Details next to the Secrets engines
#    Select enable new engine
#    Select PKI Certificates
#    Keep Path as 'pki'
#    Set Max Lease TTL to 87600 hours
#    Submit Enable engine
#
#    On the pki Overview Tab it will complain that the PKI is not configured.
#    Select Configure PKI
#    Select Generate Root
#    On Root parameters - 
#      Type - select internal
#      Common name - example.com
#      Issuer name - root-2024
#      Not valid after - TTL 87600 hours
#      Within the Issuer URLs
#        Issuing certificates    - https://localhost:8200/v1/pki/ca
#        CRL distribution points - https://localhost:8200/v1/pki/crl
#        OCSP Servers            - https://localhost:8200/v1/ocsp    
#    Select Done
#
#    The View Root Certificate Screen appears. Next to the Certificate Pem Format
#      Select the Copy icon to copy the cert to the clipboard.
#      Save the copied cert as root_2024_ca.crt ( In $WORKDIR/crypto is a good place )
#
#    Return to the Dashboard screen
#
#    Add a Role for the root CA - Select pki -> Roles (The Tab) -> Create Role
#      Role Name - 2024-servers
#      Select Create
# 
#    Note you can verify and review the cert information with 
#    openssl x509 -in ${WORKDIR}/crypto/root_2024_ca.crt -text 
#  
# Step 2. Generate Intermediate CA
#    Select Secrets Engines on left and then Enable new engine
#    Select PKI Certificates
#      Path - pki_int
#      Max lease TTL - 43800 hours
#      Select Enable Engine 
#    The pki_int Overview screen will complain that the pki is not configured.    
#    Select Configure PKI
#    Select Generate Intermediate CSR
#      Type - internal
#      Common Name - example.com Intermediate Authority
#      Select Generate
#    On View Generated CSR 
#      Select the copy icon next to the CSR Pem and copy to clipboard.
#      Save the pem file as pki_intermediate.csr ($WORKDIR/csr a good place)
#
#    Now we need to sign the CSR with the Root CA.
#    Return to Dashboard - select pki Secrets engine -> Select Issuers tab
#    Select root-2024 issuer
#    Select Sign Intermediate tab
#      Paste Pem CSR into CSR field
#      Common name - example.com
#      Format      - pem_bundle
#      Select Save to sign
#
#    Copy Certificate via copy icon. Save to intermediate_cert.pem
#    Copy and save Issuing CA and CA Chain
#
#    Go to Dashboard -> select pki_int from Secrets engines
#    Select Configure PKI
#    Select Import a CA
#    PEM Bundle - Browse to and select the intermediate_cert.pem file you saved.
#    Select Import Issuer
#    Select Done
#
# Step 3. Create a Role
#    Using a terminal obtain the issuer id:
#      kubectl exec -it -n vault vault-0 -- vault read -field=default pki_int/config/issuers
#    Copy the id output
#  
#    From Dashboard -> pki_int -> Roles (View roles) -> Create Role
#    On Create a PKI Role 
#     Role name - example-dot-com
#     Toggle off the Use default Issuer
#       Select the issuer with the id output in the terminal step above
#     Under Not valid after enter TTL - 43800 hours
#     Expand Domain Handling
#       Turn on Allow subdomains
#       In Allowed domains enter - example.com
#       Select Create
#
# Step 4. Request Certificates
#    From Dashboard -> select pki_int -> Roles (View Roles) -> example-dot-com
#    Select the Generate certificate tab
#       Common name - test.example.com
#       Under Not Valid after - set TTL 24 hours
#       Select Generate

# Go to last section of this doc - Request Certificates from Intermediate CA

####################################################################################
# ****************** Note - These steps below are a duplicate of the UI Steps ******
# As such if you performed the UI steps DO NOT do these steps.

# Beware Note - Although the steps successfully perform, in the end certificate
#               generation encounters errors when following these steps. TBD

#Enable pki engine
kubectl exec -it -n vault vault-0 -- vault secrets enable pki

#Tune cert TTL to 1 year
kubectl exec -it -n vault vault-0 -- vault secrets tune -max-lease-ttl=8760h pki

#Generate root CA cert 
#kubectl exec -it -n vault vault-0 -- vault write -field=certificate pki/root/generate/internal \
#     common_name="example.com" \
#     issuer_name="root-2024" \
#     ttl=8760h > ${WORKDIR}/root_2024_ca.crt
# Without the -field=certificate
kubectl exec -it -n vault vault-0 -- vault write pki/root/generate/internal \
     common_name="example.com" \
     issuer_name="root-2024" \
     ttl=8760h > ${WORKDIR}/root_2024_ca.crt
     
# Configure the certficate issuing and revocation list endpoints.
kubectl exec -it -n vault vault-0 -- vault write pki/config/urls \
    issuing_certificates="http://vault.vault:8200/v1/pki/ca" \
    crl_distribution_points="http://vault.vault:8200/v1/pki/crl"          

#List the issuer info for the root CA
kubectl exec -it -n vault vault-0 -- vault list pki/issuers/


##########################################################################
#Switching to modified curl api calls as the vault cli with or without kubectl throws
# tls: failed to verify certificate: x509: certificate signed by unknown authority
# for some of the command steps

#Step 5 - List the issuer metadata and usage info
#kubectl exec -it -n vault vault-0 -- vault read pki/issuers/$(vault list -format=json pki/issuers/ | jq -r '.[]') tail -n 6
curl --cacert $WORKDIR/vault.ca \
     --silent \
     --header "X-Vault-Request: true" \
     --header "X-Vault-Token: $(vault print token)" \
     https://127.0.0.1:8200/v1/pki/issuers\?list=true \
     | jq
    
#Step 6 - Create a role for the issuer
# **** Important - 2 values need to be provided 
          1.) the ADMIN_TOKEN - try echo $ADMIN_TOKEN, if this does not work try
              ADMIN_TOKEN=$(kubectl exec -it -n vault vault-0 -- vault token create -format=json -policy="admin" | jq -r ".auth.client_token")
          2.) the "keys" value from the prior Step 5 output needs to be copied to the 
#              keys value within the command below.
#kubectl exec -it -n vault vault-0 -- vault write pki/roles/2024-servers allow_any_name=true
curl --cacert $WORKDIR/vault.ca \
     --silent \
     --header "X-Vault-Token: <ADMIN_TOKEN>" \
     --header "X-Vault-Request: true" \
     https://127.0.0.1:8200/v1/pki/issuer/<keys value> \
     | jq
# command with substituted values
curl --cacert $WORKDIR/vault.ca \
     --silent \
     --header "X-Vault-Token: hvs.CAESIK5Dd1u4_O7QOCqYQ0g6ttI_tx_hnZqcMih13wBnpjI2Gh4KHGh2cy5NNXlURlhEaEVCN1k1d3FkdTFBVVFKdmc" \
     --header "X-Vault-Request: true" \
     https://127.0.0.1:8200/v1/pki/issuer/4a02cd8f-89cb-3a8e-4b87-483bc1775424 \
     | jq

#Step 7 - Configure CA and CRL URLs
kubectl exec -it -n vault vault-0 -- vault write pki/config/urls \
     issuing_certificates="https://127.0.0.1:8200/v1/pki/ca" \
     crl_distribution_points="https://127.0.0.1:8200/v1/pki/crl"
     
################# Now Generate an intermediate cert

#Enable pki at the pki_int path
kubectl exec -it -n vault vault-0 -- vault secrets enable -path=pki_int pki

#Tune TTL for certs
kubectl exec -it -n vault vault-0 -- vault secrets tune -max-lease-ttl=43800h pki_int

#Use the pki issue command to manage intermediate cert generation workflow.
#IMPORTANT - Copy in the issuer key id
kubectl exec -it -n vault vault-0 -- vault pki issue \
      --issuer_name=example-dot-com-intermediate \
      /pki/issuer/<key id> \
      /pki_int/ \
      common_name="example.com Intermediate Authority" \
      o="example" \
      ou="education" \
      key_type="rsa" \
      key_bits="4096" \
      max_depth_len=1 \
      permitted_dns_domains="test.example.com" \
      ttl="43800h"
# Command with substituted issuer key id
kubectl exec -it -n vault vault-0 -- vault pki issue \
      --issuer_name=example-dot-com-intermediate \
      /pki/issuer/4a02cd8f-89cb-3a8e-4b87-483bc1775424 \
      /pki_int/ \
      common_name="example.com Intermediate Authority" \
      o="example" \
      ou="education" \
      key_type="rsa" \
      key_bits="4096" \
      max_depth_len=1 \
      permitted_dns_domains="test.example.com" \
      ttl="43800h"

#Create a role
DEFAULT_ISSUER=$(kubectl exec -it -n vault vault-0 -- vault read -field=default pki_int/config/issuers)
echo $DEFAULT_ISSUER
kubectl exec -it -n vault vault-0 -- vault write pki_int/roles/example-dot-com \
     issuer_ref="${DEFAULT_ISSUER}" \
     allowed_domains="example.com" \
     allow_subdomains=true \
     max_ttl="720h"
 
####################################################################################
########## End duplicate Steps with the UI steps ################################### 
 

####################################################################################
########### Note - These steps in requesting a new Cert work if you performed
# the setup with the UI.They generate errors when the steps with kubectl above are
# performed.

################################################################################
# Request Certificates from Intermediate CA
kubectl exec -it -n vault vault-0 -- vault write pki_int/issue/example-dot-com common_name="test2.example.com" ttl="24h"     

# This curl command is an alternative to the above. If using it remember the 
# string substitution.
curl --cacert $WORKDIR/crypto/vault.ca \
     --header "X-Vault-Token: ${ADMIN_TOKEN}" \
     --request POST \
     --data '{"common_name": "test3.example.com", "ttl": "24h"}' \
     https://127.0.0.1:8200/v1/pki_int/issue/example-dot-com | jq
     
# This Step 4. is now complete.     

