#!/bin/bash

if [ -f "/local/ready" ]; then
    echo "kOperator RIC already installed."
    exit 1
fi

BASE_DIR="/local"

# Redirect output to log file
exec >> ${BASE_DIR}/deploy.log
exec 2>&1

# Go to BASE_DIR
cd $BASE_DIR

# Update apt
sudo apt update -y

# Clone OAIC repository and sub-repositories
git clone https://github.com/openaicellular/oaic.git
cd oaic/
git submodule update --init --recursive --remote

# Enable xApp Onboarder support
cd RIC-Deployment/

# Install Kubernetes, Docker and Helm
cd tools/k8s/bin/
./gen-cloud-init.sh
# Patch generated script to avoid reboot
sed -i "s/reboot/date/g" ./k8s-1node-cloud-init-k_1_16-h_2_17-d_cur.sh
sudo ./k8s-1node-cloud-init-k_1_16-h_2_17-d_cur.sh

# Initialize Helm
sudo helm init --client-only
sudo helm repo update

# Setup Influxdb
sudo kubectl create ns ricinfra
sudo helm install stable/nfs-server-provisioner --namespace ricinfra --name nfs-release-1
sudo kubectl patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
sudo apt install -y nfs-common

# Build local Docker image of the e2term
cd $BASE_DIR/oaic/ric-plt-e2/RIC-E2-TERMINATION/
sudo docker build -f Dockerfile -t localhost:5001/ric-plt-e2:5.5.0 .
sudo docker push localhost:5001/ric-plt-e2:5.5.0

# Patch influxDB PVC
cd $BASE_DIR/oaic/RIC-Deployment/bin/
sed -i "s/8Gi/5Gi/g" ../ric-dep/helm/3rdparty/influxdb/values.yaml

# Deploy RIC
sudo ./deploy-ric-platform -f ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml


echo "Installation completed"
date
touch /local/ready