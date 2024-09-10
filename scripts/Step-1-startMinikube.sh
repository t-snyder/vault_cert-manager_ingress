#!/bin/bash

# Open terminal 1
# Delete prior minikube
minikube delete

# Start minikube - configure the settings to your requirements and hardware
minikube start --cpus 4 --memory 12288 --vm-driver kvm2 --disk-size 100g --insecure-registry="192.168.39.0/24"

# Addons
minikube addons enable dashboard
minikube addons enable metrics-server
minikube addons enable ingress-nginx

# Start dashboard
minikube dashboard

# Start a 2nd terminal to mount a local drive into minikube. The local drive path
# will be the directory which contains the kube deployment files and in later steps the
# generated keys for vault. Mount this directory to the minikube /data directory/
WORKDIR=/media/tim/ExtraDrive1/Projects/learn-hashicorp-vault/vault-tls
ls $WORKDIR
minikube mount $WORKDIR/kube:/data

# 
# Go to a 3rd terminal - ssh into the running minikube instance
minikube ssh

# At the minikube prompt - switch to sudo
sudo -i

# Change to /etc/kubernetes directory within the minikube environment
cd /etc/kubernetes

# Create the directory to hold the apiserver encryption config file and go to it.
mkdir enc
cd enc

# Copy the encryptConfig.yaml from your local machine directory which has been mounted
# in the /data directory of the minikube environment to this new directory.
cp /data/encryptConfig.yaml .

# Now change to the /etc/kubernetes/manifests directory. There you should be able to 
# see the kube-apiserver.yaml file. The minikube processes watch this file for changes.
# When the yaml is changed the kube-apiserver-minikube pod will be reapplied.
cd ../manifests

# Edit the apiserver.yaml to enable etcd encryption
vi kube-apiserver.yaml

# There are 3 additions that need to be made. 
# The first - add the following line to the spec.containers.command arguments
    - --encryption-provider-config=/etc/kubernetes/enc/encryptConfig.yaml  # add this line

# The second - add an additional volumeMounts
    - mountPath: /etc/kubernetes/enc
      name: enc
      readOnly: true

# The third - add an additional volume to the volumes
  - hostPath:
      path: /etc/kubernetes/enc
      type: DirectoryOrCreate
    name: enc

# Save and quit
{ESC}:wq

exit {sudo}
exit {ssh}

# Note - You may have to delete and restart the minikube dashboard in order to see
# the updates to the apiserver. It takes approximately 1 minute to restart.
#
# In the browser kubernetes dashboard watch the kube-apiserver-minikube pod get updated.
# After it is - to validate the apiserver config has been updated:
minikube ssh

# At the minikube shell - In the output you should see the 
# "encryption-provider-config=/etc/kubernetes/enc/encryptConfig.yaml". It will be in the 
# argument order you added it to. (May have to wait a few seconds)
ps aux | grep "kube-apiserver" | grep "encryption-provider-config"     
 
exit {ssh}

# The update to the apiserver will now encryt new secrets. However prior secrets will
# still be stored in etcd in base64 plaintext. To update these secrets to be encrypted
# perform the following:
kubectl get secrets --all-namespaces -o json | kubectl replace -f -

# Let's create a new secret
kubectl create secret generic -n default a-secret --from-literal=key1=supersecret

# We will now validate the new secret in 2 ways. First to ensure that within the etcd
# storage that it is in fact encrypted, and second that we can retrieve the secret info
# decrypted.

# First start a shell in the etcd pod
kubectl exec -it -n=kube-system etcd-minikube -- /bin/sh

# Obtain and display the secret. The output should be in encrypted form.
ETCDCTL_API=3 etcdctl \
--cacert /var/lib/minikube/certs/etcd/ca.crt \
--cert /var/lib/minikube/certs/etcd/server.crt \
--key /var/lib/minikube/certs/etcd/server.key \
get /registry/secrets/default/a-secret

exit

# Now let's obtain and display the secret in plaintext. The output should be 'supersecret'.
echo `kubectl get secrets -n default a-secret -o jsonpath='{.data.key1}'` | base64 --decode

# This step setup is completed. We can now continue with the steps in setting up the 
# Hashicorp vault - Step-2-deployVaultTLS.sh
