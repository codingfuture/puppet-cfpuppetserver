#!/bin/bash

repourl=$1
certname=${2:-$(hostname --fqdn)}
cflocation=$3
cflocationpool=$4
http_proxy=${5:-$http_proxy}
autosign=${INSANE_PUPPET_AUTOSIGN:-false}

if test -z "$repourl"; then
    echo "Usage: $0 <r10k_repo_url> [<certname=hostname> [<cflocation> [<cflocationpool> [<http_proxy=$http_proxy>] ] ] ]"
    exit 1
fi

if test "$(id -un)" != 'root'; then
    echo 'This script must run as root'
    exit 1
fi

if test ! -z "$cflocation"; then
    echo -n $cflocation >/etc/cflocation
fi
if test ! -z "$cflocationpool"; then
    echo -n $cflocationpool >/etc/cflocationpool
fi

if test ! -z "$http_proxy"; then
    export http_proxy
    export https_proxy="$http_proxy"
    export HTTP_PROXY="$http_proxy"
    export HTTPS_PROXY="$http_proxy"
fi

echo $certname > /etc/hostname
hostname $certname

if ! which lsb-release | read; then
    apt-get install -y lsb-release
fi


export DEBIAN_FRONTEND=noninteractive

codename=$(lsb_release -cs)

if test -z "$codename"; then
    echo "Failed to detect correct codename"
    exit 1
fi

puppetlabs_deb="puppetlabs-release-pc1-${codename}.deb"
echo "Retrieving $puppetlabs_deb"
wget -q https://apt.puppetlabs.com/$puppetlabs_deb
echo "Installing $puppetlabs_deb"
dpkg -i $puppetlabs_deb

mkdir -p /etc/puppetlabs/puppet

cat >/etc/puppetlabs/puppet/puppet.conf <<EOF
[main]
certname = $certname
server = $certname
ca_server = $certname
environment = production

environment_data_provider = hiera

[master]
vardir = /opt/puppetlabs/server/data/puppetserver
logdir = /var/log/puppetlabs/puppetserver
rundir = /var/run/puppetlabs/puppetserver
pidfile = /var/run/puppetlabs/puppetserver/puppetserver.pid
codedir = /etc/puppetlabs/code

# !!! NOT FOR PRODUCTION !!!
autosign = $autosign

EOF

echo "Running apt-get update ..."
apt-get update || exit 1

echo "Installing puppet-agent"
apt-get install \
        -f -y \
        -o Dpkg::Options::="--force-confold" \
        git \
        puppet-agent
    
totalmem=$(( $(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
psmem=$(( $totalmem / 4 ))

# Setup self
#---
PUPPET=/opt/puppetlabs/bin/puppet

echo "Installing puppetserver"
$PUPPET resource package puppetserver ensure=latest
sed -i -e "s/^.*JAVA_ARGS.*$/JAVA_ARGS=\"-Xms${psmem}m -Xmx${psmem}m\"/g" \
    /etc/default/puppetserver
echo "Running puppetserver & agent to generate SSL keys for PuppetDB"
$PUPPET resource service puppetserver ensure=running enable=true
$PUPPET agent --test

# Setup postgres
#---
echo "Installing postgresql"
$PUPPET resource package postgresql ensure=latest
$PUPPET resource package postgresql-contrib ensure=latest
echo "Configuring postgresql"
sudo -u postgres createuser -DRS puppetdb
sudo -u postgres psql -c "ALTER USER puppetdb WITH PASSWORD 'puppetdb';"
sudo -u postgres createdb --locale=en_US.utf8 -E UTF8 -O puppetdb -T template0 puppetdb
sudo -u postgres psql puppetdb -c 'create extension pg_trgm'
for f in /etc/postgresql/*/main/pg_hba.conf; do
    cat >$f <<EOCONF
# TYPE  DATABASE   USER   CIDR-ADDRESS  METHOD
local   all        all                  md5
host    all        all    127.0.0.1/32  md5
host    all        all    ::1/128       md5    
EOCONF
done
sed -i -e "s/^.*shared_buffers.*$/shared_buffers = ${psmem}MB/g" \
    /etc/postgresql/*/main/postgresql.conf

service postgresql restart

# Setup puppet DB
#---
echo "Installing puppetdb"
$PUPPET resource package puppetdb ensure=latest
sed -i -e "s/^.*JAVA_ARGS.*$/JAVA_ARGS=\"-Xms${psmem}m -Xmx${psmem}m\"/g" \
    /etc/default/puppetdb
cat >/etc/puppetlabs/puppetdb/conf.d/database.ini <<EOCONF
[database]
classname = org.postgresql.Driver
subprotocol = postgresql
subname = //localhost:5432/puppetdb
username = puppetdb
password = puppetdb
log-slow-statements = 10
EOCONF
$PUPPET resource service puppetdb ensure=running enable=true
service puppetdb restart

# Connect PuppetMaster to PuppetDB
$PUPPET resource package puppetdb-terminus ensure=latest
grep $certname /etc/hosts | read || \
    $PUPPET resource host $certname ip=$(/opt/puppetlabs/bin/facter networking.ip)

cat >>/etc/puppetlabs/puppet/puppet.conf <<EOCONF

# puppetdb-related
storeconfigs = true
storeconfigs_backend = puppetdb
reports = store,puppetdb
# TO BE OVERWRITTEN
EOCONF
cat >/etc/puppetlabs/puppet/puppetdb.conf <<EOCONF
[main]
server_urls = https://$certname:8081
# TO BE OVERWRITTEN
EOCONF
cat >/etc/puppetlabs/puppet/routes.yaml <<EOCONF
---
master:
  facts:
    terminus: puppetdb
    cache: yaml
# TO BE OVERWRITTEN
EOCONF

cat >/etc/puppetlabs/code/hiera.yaml <<EOCONF
---
:backends:
  - yaml
:hierarchy:
  - global
:yaml:
  # Make sure to use hiera.yaml in environments
  :datadir: "/etc/puppetlabs/code/hieradata"
# TO BE OVERWRITTEN
EOCONF
mkdir -p /etc/puppetlabs/code/hieradata
cat >/etc/puppetlabs/code/hieradata/global.yaml <<EOCONF
---
{}
# TO BE OVERWRITTEN
EOCONF

chown -R puppet:puppet `puppet config print confdir`
chown -R puppet:puppet /etc/puppetlabs/code

echo "Enabling puppetdb & puppetserver services"
systemctl enable puppetdb puppetserver

# r10k
#----
echo "Installing r10k"
mkdir -p /etc/puppetlabs/r10k/
cat >/etc/puppetlabs/r10k/r10k.yaml <<EOCONF
# The location to use for storing cached Git repos
:cachedir: '/opt/puppetlabs/r10k/cache'

# A list of git repositories to create
:sources:
  :conf:
    remote: '$repourl'
    basedir: '/etc/puppetlabs/code/environments'
# TO BE OVERWRITTEN
EOCONF

mkdir -p /opt/codingfuture/bin
cat >/opt/codingfuture/bin/cf_r10k_deploy <<EOCONF
#!/bin/bash

export PATH="/opt/puppetlabs/bin/:/opt/puppetlabs/puppet/bin/:\$PATH"
/opt/puppetlabs/puppet/bin/r10k deploy environment

for penv in /etc/puppetlabs/code/environments/*; do
    pushd \$penv >/dev/null
    /opt/puppetlabs/puppet/bin/librarian-puppet install
    popd >/dev/null
done

chown -R puppet:puppet /etc/puppetlabs/code/environments/
# TO BE OVERWRITTEN
EOCONF
chmod 750 /opt/codingfuture/bin/cf_r10k_deploy

/opt/puppetlabs/puppet/bin/gem install r10k

echo "Installing librarian-puppet"
/opt/puppetlabs/puppet/bin/gem install activesupport
/opt/puppetlabs/puppet/bin/gem install librarian-puppet

echo "Restarting puppetdb & puppetserver"
service puppetdb restart
service puppetserver restart
#---
true
