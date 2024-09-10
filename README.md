The script files within the /script directory go through a series of deployment steps.

| Step # | File Commands  |
|-----:|---------------|
|     1| Step-1-startMinikube.sh              |
|     2| Step-2-deployVaultTLS.sh              |
|     3| Step-3-deployVaultSetup.sh              |
|     4| Step-4-configVaultCA.sh            |
|     5| Step-5-vaultIssuerSetup.sh |
|     6| Step-6-PapayaSetup.sh       |

The particular versions that these prototypes were generated and tested with are:
Ubuntu - 20.04

Minikube Bundle
  Minikube - 1.33
  Kubernetes - 1.30
  Docker 26.0.1
  etcd-v3
  
Vault - 1.17.3
Cert-Manager - 1.14.5
jq - 1.6
  
****** Note
The steps with the the files are not automated, but expected to be run 1 at a time. The
main issue is the string substitions as well as the shell logins into the vault pods
which are part of some of the steps.

Step 1 - Start Minikube.sh
Within these steps minikube and addons are installed. After the initial deployment
the apiserver.yaml is changed to encrypt the etcdv3 storage. Existing secrets are 
then converted from plaintext to being encrypted, and the storage is finally tested.
**************************************************************************************

Step 2 - Create and Deploy crypto assets in preparation for using the Vault with TLS.
Main documentation - https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls
This step creates and configures keys and certificates for use within vault for TLS. The
certificate is signed by kubernetes. After generation vault is deployed using the Vault 
Helm chart.
**************************************************************************************

Step 3 - Deploy Vault Setup (Configure, join and unseal)
Main documentation - https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls
This step first generates the unseal keys for the vault pods. Vault-0 is first unsealed,
and then vault-1 and vault-2 are joined to vault-0. After being joined vault-1 and vault-2
are unsealed. The generated cluster key is then used to login to vault. After this several
tests are done to ensure the vault is in working order.
**************************************************************************************

*************** Note ******************
At this point vault and etcd are working. However if minikube goes down due to logging
out, crash, etc. then when minikube is restarted 2 things need to happen after restart.
The first - when minikube starts is uses an internal standard apiserver.yaml. This 
configuration needs to be modified to provide the encrytion for etcd. Second the vault
pods need to be unsealed again. These steps are outlined within the restartMinikube.sh
**************************************************************************************

Step 4 - Configure the Vault as a Certificate Authority.
Main document - https://developer.hashicorp.com/vault/tutorials/secrets-management/pki-engine
The steps to configure the Vault as a CA involve setting up the Root CA and then an
intermediate CA. I could successfully get the Vault UI steps to generate the artifacts
and subsequently generate certificates. The cli steps work, but in the end when trying 
to generate certificates there is an error. 
**************************************************************************************

Step 5 - Vault Issuer Setup
Main document 1 - https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
Main document 2 - https://cert-manager.io/docs/configuration/vault/
These steps set up the roles, role bindings, service accounts and authentication to
allow vault to act as a certificate issuer for cert-manager. These steps are performed
from the point of view of Vault.
**************************************************************************************

Step 6 - Papaya Setup
Main document 1 - https://developer.hashicorp.com/vault/tutorials/archive/kubernetes-cert-manager
Main document 2 - https://cert-manager.io/docs/configuration/vault/
These steps generate a new intermediate CA specifically for the foo.com urls to which 
papaya belongs. They first use the Vault UI as in Step 5 above to create the new
intermediate CA. From there they use the cert-manager yaml files to create the ingress
and generate the tls certificates via the new vault-issuer. A simple test is then
provided.


