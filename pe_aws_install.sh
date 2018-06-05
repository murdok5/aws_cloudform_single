#!/bin/bash

#Set Parameters and network
#version="2017.3.5"
export PATH=/opt/puppetlabs/bin:$PATH
export HOME=/root
hostname $(curl http://169.254.169.254/latest/meta-data/local-hostname)
echo $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) $(hostname) >> /etc/hosts

#Enable autosign
mkdir -p /etc/puppetlabs/puppet
echo '*' > /etc/puppetlabs/puppet/autosign.conf

#download PE
#retrycurl() { set +e; while :; do curl "$@"; [ "$?" = 0 ] && break; done; set -e; }
#retrycurl --max-time 30 -O "https://s3.amazonaws.com/pe-builds/released/$version/puppet-enterprise-$version-el-7-x86_64.tar.gz"
curl -O https://s3.amazonaws.com/pe-builds/released/2018.1.0/puppet-enterprise-2018.1.0-el-7-x86_64.tar.gz
tar -xzf puppet-enterprise-2018.1.0-el-7-x86_64.tar.gz
cat > pe.conf <<-EOF
{
  "console_admin_password": "puppetlabs"
  "puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
}
EOF

#Install PE
./puppet-enterprise-$version-el-7-x86_64/puppet-enterprise-installer -c pe.conf

#manually run puppet to completion
/opt/puppetlabs/bin/puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff --no-use_cached_catalog

echo COMPLETE
