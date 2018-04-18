#!/bin/bash

#Set Parameters and network
version="2017.3.5"
export PATH=/opt/puppetlabs/bin:$PATH
export HOME=/root
hostname $(curl http://169.254.169.254/latest/meta-data/local-hostname)
echo $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) $(hostname) >> /etc/hosts
nc_url="https://$hostname:4433/classifier-api/v1"

#Enable autosign
mkdir -p /etc/puppetlabs/puppet
echo '*' > /etc/puppetlabs/puppet/autosign.conf

#down
retrycurl() { set +e; while :; do curl "$@"; [ "$?" = 0 ] && break; done; set -e; }
retrycurl --max-time 30 -O "https://s3.amazonaws.com/pe-builds/released/$version/puppet-enterprise-$version-el-7-x86_64.tar.gz"
tar -xzf puppet-enterprise-$version-el-7-x86_64.tar.gz
cat > pe.conf <<-EOF
{
  "console_admin_password": "puppetlabs"
  "puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
  "puppet_enterprise::profile::master::r10k_remote": "https://github.com/puppetlabs-seteam/control-repo"
  "puppet_enterprise::profile::master::code_manager_auto_configure": true
}
EOF

#Install PE
./puppet-enterprise-$version-el-7-x86_64/puppet-enterprise-installer -c pe.conf

#Create non-admin user (tse)
#Needed because admin user cannot issue code deployments through code manager
curl -H "Content-Type: application/json" -X POST -d '{"login":"codemanager", "email":"codemanager@company.com", "display_name":"CodeManager", "role_ids":[1], "password":"puppetlabs" }' \
  --cert `puppet config print hostcert` \
  --key `puppet config print hostprivkey` \
  --cacert `puppet config print cacert` \
  "https://$hostname:4433/rbac-api/v1/users"

#Get access token needed for code deploy (Code manager API does not support white listed certificates for auth)
mkdir -p /root/.puppetlabs
curl --cacert `puppet config print cacert` -X POST -H 'Content-Type: application/json' \
  -d '{"login": "codemanager", "password": "puppetlabs", "lifetime": "5y", "label": "five-year token"}' \
  "https://$hostname:4433/rbac-api/v1/auth/token" | python -c 'import sys, json; print json.load(sys.stdin)["token"]'>/root/.puppetlabs/token
token=$(cat /root/.puppetlabs/token)
echo $(token)

#deploy code
curl -k -X POST -H 'Content-Type: application/json' -H "X-Authentication: $token" -d '{"deploy-all": true, "wait": true}' "https://$hostname:8170/code-manager/v1/deploys"
puppet code deploy production

#manually run puppet to completion
/opt/puppetlabs/bin/puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff --no-use_cached_catalog
/opt/puppetlabs/bin/puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff --no-use_cached_catalog
/opt/puppetlabs/bin/puppet agent --onetime --verbose --no-daemonize --no-usecacheonfailure --no-splay --show_diff --no-use_cached_catalog

echo COMPLETE
