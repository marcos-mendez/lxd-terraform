#!/bin/bash
sudo snap install microk8s --classic
sudo usermod -a -G microk8s ubuntu
sudo chown -f -R ubuntu ~/.kube
echo 'alias kubectl="microk8s kubectl"' >> ~/.bashrc
source ~/.bashrc
JOIN_TOKEN=$(cat ../../join_token.txt)
sudo microk8s join --token ${JOIN_TOKEN} ${1}:25000
