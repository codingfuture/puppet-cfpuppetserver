# cfpuppetserver

## Description

The package does standard procedure of installing Puppet Server, Puppet DB, PostgreSQL,
r10k, librarian-puppet and making it work all togather. It also lives in peace with
[cfsystem][] and [cfnetwork][] packages.

### Environment configuration

The configurations expects you to provide [Hiera version 4 configuration](https://docs.puppetlabs.com/puppet/latest/reference/lookup_quick.html#hierayaml-version-4-in-a-nutshell)
in environments. Example can be taken from [codingfuture/puppe-test](https://github.com/codingfuture/puppet-test/blob/master/hiera.yaml).

**NOTE1: there is a known closed bug in puppet <=4.3.2 - please make sure that all Hiera hierarchy files exist and both empty YAML and JSON files include '{}' at least**

## VERY IMPORTANT!!!

Now, the modules uses [cfdb][] for High Availability support out-of-the-box. The consequences is
that setup process is quite tricky - we need some facts and resources to be populated into Puppet DB
while Puppet DB is malfunctioning until the stack is fully configured.
Most likely, you will see some errors during conversion process and both Puppet DB & Puppet Server
**stop functioning**.

In that case, you can continue re-provisioning previously compiled catalog until Puppet Server 
can continue compiling new catalogs with the following command:

```bash
/opt/puppetlabs/bin/puppet apply --catalog /opt/puppetlabs/puppet/cache/client_data/catalog/$(/bin/hostname --fqdn).json
/opt/puppetlabs/bin/puppet agent --test
```

## Upgrade to puppetserver >= 2.5.0

As there is incompatible change related to bootstrap.cfg, please use `cfpuppetserver` < v0.10 for puppetserver < 2.5.

Upgrade procedures:

* Update to `cfpuppetserver` >= v0.10
* Manually deploy to current Puppet servers: `puppet agent -t`
* Puppet Server will fail to restart in 180 seconds
* Upgrade `puppetserver`/`puppetdb`/`puppet-agent` packages to latest versions
* Manually start services:
    * /bin/systemctl stop cfpuppetdb.service cfpuppetserver.service
    * /bin/systemctl start cfpuppetdb.service cfpuppetserver.service
* Wait for services to startup monitoring `netstat -pletn`
* Try Puppet deployment


## Global Hiera config

Puppet 4 has own implementation of lookup() which goes through:

* Global Hiera
* Per-environment Data Providers (Hiera, custom function)
* Per-module Data Providers (Hiera, custom function)

You should not use global Hiera any more. All configurations should be set in environments as mentioned above.

Global Hiera config is as follows:

```yaml
---
:backends:
  - yaml
:hierarchy:
  - global
:yaml:
  # Make sure to use hiera.yaml in environments
  :datadir: "/etc/puppetlabs/code/hieradata"
```

### Adding new Puppet clients

This module also provides a handy tool to initalize new puppet client hosts:

```
~#  /opt/codingfuture/bin/cf_gen_puppet_client_init
Usage: cf_gen_puppet_client_init <certname> [<cflocation> [<cflocationpool> [<http_proxy>]]
```

### Manual (re-)deployment of Puppet environments

```
~# /opt/codingfuture/bin/cf_r10k_deploy
```

### Automatic deployment via VCS (git) hook
```
~# ssh deploypuppet@puppet.example.com sudo /opt/codingfuture/bin/cf_r10k_deploy
```


## Setup

### Initial Puppet Server infrastructure

Either do manually (preferred for self-education) or use bundled [setup script](https://github.com/codingfuture/puppet-cfpuppetserver/blob/master/setup_puppetserver.sh):
```
~# ./setup_puppetserver.sh
Usage: ./setup_puppetserver.sh <r10k_repo_url> [<certname=hostname> [<cflocation> [<cflocationpool> [<http_proxy=$http_proxy>] ] ] ]
```

### Config for Puppet Server node

Please use [librarian-puppet](https://rubygems.org/gems/librarian-puppet/) to deal with dependencies.
If this module is used for server setup then librarian-puppet is installed automatically.

There is a known r10k issue [RK-3](https://tickets.puppetlabs.com/browse/RK-3) which prevents
automatic dependencies of dependencies installation.

## Examples

Please check [codingufuture/puppet-test](https://github.com/codingfuture/puppet-test) for
example of a complete infrastructure configuration and Vagrant provisioning.


## `cfpuppetserver` class

* `deployuser = 'deploypuppet'` - user name for auto deploy user for VCS hook
* `deployuser_auth_keys = undef` - list of ssh_authorized_keys configurations
* `repo_url = undef` - repository location in URI format (e.g. ssh://user@host/repo or file:///some/path)
* `puppetserver = true` - if true then assume Puppet Server lives on this host (affects firewall)
* `puppetdb = true` - if true then assume Puppet DB lives on this host (affects firewall)
* `postgresql = true` - if true then PostgreSQL is setup on this node
* `iface = 'any'` - `cfnetwork::iface` name to listen for incoming client connections
* `cluster = 'cfpuppet'` - `cfdb` cluster to use
* `database = 'puppetdb' - `cfdb::database` to use in cluster
* `is_cluster = false` - goes directly to `cfdb::instance`
* `is_secondary = false` - goes directly to `cfdb::instance`
* `allow_update_check = false` - open firewall to connect to updates.puppetlabs.com, if enabled

## `cfpuppetserver::postgresql` class

NOTE: if PostgreSQL is setup through this module then you SHOULD NOT setup other cfdb instances
on the same node.

* `$settings_tune = {}`  - goes directly to `cfdb::instance`
* `$port = 5432` - goes directly to `cfdb::instance`
* `$node_id = undef` - required, if node ID cannot be retrieved from hostname in cluster mode
* `$password = undef` - force specific password instead of random generated
* `$memory_weight = 200` - goes directly to `cfdb::instance`
* `$memory_max = undef` - goes directly to `cfdb::instance`
* `$cpu_weight = 200` - goes directly to `cfdb::instance`
* `$io_weight = 200` - goes directly to `cfdb::instance`

## `cfpuppetserver::puppetdb` class

* `$use_proxy = 'secure'` - by default TLS channel is used for remote PostgreSQL connections. See `cfdb::access`.
* `$port = 8081` - port to use for PuppetDB instance
* `$max_connections = 30` - maximum number of connections per pool (there are two pools)
* `$memory_weight = 100` - relative weight for auto-distribution of memory resources
* `$memory_max = 256` - max memory in MB
* `$cpu_weight = 100` - relative weight for auto-distribution of CPU resources
* `$io_weight = 100` - relative weight for auto-distribution of I/O resources
* `$cert_whitelist = undef` - specify the CNs of Puppet PKI to be accepted.
    If not set:
    * if Puppet Server runs the same node then `[$fqdn]`
    * otherwise, all nodes with Puppet Server configured
* `$settings_tune = {}` - a tree structure of PuppetDB INI for fine control

## `cfpuppetserver::puppetserver` class

* `$autosign = false` - DO NOT use in production. Enable auto-sign of client certificates.
* `$global_hiera_config = 'cfpuppetserver/hiera.yaml'` - default global Hiera config
* `$memory_weight = 100` - relative weight for auto-distribution of memory resources
* `$memory_max = undef` - max memory in MB
* `$cpu_weight = 100` - relative weight for auto-distribution of CPU resources
* `$io_weight = 100` - relative weight for auto-distribution of I/O resources
* `$activesupport_ver = '4.2.7.1'` - version of activesupport gem to install


[cfnetwork]: https://github.com/codingfuture/puppet-cfnetwork
[cfsystem]: https://github.com/codingfuture/puppet-cfsystem
