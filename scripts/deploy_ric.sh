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
git checkout e_rel_xapp_onboarder_support
git submodule update --init --recursive --remote

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

# Patch RIC yaml file to include our e2term container
cd $BASE_DIR/oaic/RIC-Deployment/bin/
sed -i "s/localhost:5001/docker.io/g" ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml # Registry
sed -i "114s/ric-plt-e2/j0lama\/koperator_e2term/" ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml # Name
sed -i "s/5.5.0/latest/g" ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml # Tag

# Patch influxDB PVC
sed -i "s/8Gi/5Gi/g" ../ric-dep/helm/3rdparty/influxdb/values.yaml

# Deploy RIC
sudo ./deploy-ric-platform -f ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml


echo "Installation completed"
date
touch /local/ready