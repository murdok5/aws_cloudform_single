#!/bin/bash
sudo hostnamectl set-hostname --static
echo "\npreserve_hostname: true" >> /etc/cloud/cloud.cfg
yum install vim -y
10.0.45.180 master.puppet.cloud
