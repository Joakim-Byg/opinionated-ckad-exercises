#! /bin/bash

cd /var/tmp
# installing kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/bin

# installing helm
curl -lO https://get.helm.sh/helm-v3.18.6-linux-386.tar.gz
tar -zxvf helm-v3.18.6-linux-386.tar.gz
chmod +x linux-386/helm
sudo mv linux-386/helm /usr/bin/helm

# installing k9s
curl -LO https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_Linux_amd64.tar.gz
tar xf k9s_Linux_amd64.tar.gz
chmod +x k9s
sudo mv k9s /usr/bin

# installing KinD
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.29.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/bin/kind

# installing kustomize
curl -LO https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.7.1/kustomize_v5.7.1_linux_amd64.tar.gz
tar xf kustomize_v5.7.1_linux_amd64.tar.gz
chmod +x kustomize
sudo mv kustomize /usr/bin/kustomize