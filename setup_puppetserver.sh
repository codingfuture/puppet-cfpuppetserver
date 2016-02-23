#!/bin/bash

repourl=$1
certname=${2:-$(hostname)}
cflocation=$3
cflocationpool=$4
http_proxy=${5:-$http_proxy}
autosign=${INSANE_PUPPET_AUTOSIGN:-false}

if test -z "$repourl"; then
    echo "Usage: ./setup_puppetserver.sh <r10k_repo_url> [<certname=hostname> [<cflocation> [<cflocationpool> [<http_proxy=$http_proxy>] ] ] ]"
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

echo "Writing /etc/apt/sources.list.d/pgdg.list ..."
cat > /etc/apt/sources.list.d/pgdg.list <<EOF
deb http://apt.postgresql.org/pub/repos/apt/ ${codename}-pgdg main
#deb-src http://apt.postgresql.org/pub/repos/apt/ ${codename}-pgdg main
EOF

echo "Importing repository signing key ..."
KEYRING="/etc/apt/trusted.gpg.d/apt.postgresql.org.gpg"
test -e $KEYRING || touch $KEYRING
apt-key --keyring $KEYRING add - <<EOF
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG v1

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
IIP9up4xwgje9LB7fMxsSkCDTHOk
=s3DI
-----END PGP PUBLIC KEY BLOCK-----
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
sudo -u postgres createdb -E UTF8 -O puppetdb puppetdb
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
$PUPPET resource package puppetdb-termini ensure=latest
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
mkdir /etc/puppetlabs/code/hieradata
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

cat >/etc/puppetlabs/deploy.sh <<EOCONF
#!/bin/bash

/opt/puppetlabs/puppet/bin/r10k deploy environment

for penv in /etc/puppetlabs/code/environments/*; do
    pushd $penv
    /opt/puppetlabs/puppet/bin/librarian-puppet install
    popd
done

chown -R puppet:puppet /etc/puppetlabs/code/environments/
# TO BE OVERWRITTEN
EOCONF
chmod 750 /etc/puppetlabs/deploy.sh

/opt/puppetlabs/puppet/bin/gem install r10k

echo "Installing librarian-puppet"
/opt/puppetlabs/puppet/bin/gem install activesupport
/opt/puppetlabs/puppet/bin/gem install librarian-puppet

echo "Restarting puppetdb & puppetserver"
service puppetdb restart
service puppetserver restart
#---
true
