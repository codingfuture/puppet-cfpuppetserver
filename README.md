# cfpuppetserver

## Description

The package does standard procedure of installing Puppet Server, Puppet DB, PostgreSQL,
r10k, librarian-puppet and making it work all togather. It also lives in peace with
[cfsystem][] and [cfnetwork][] packages.

### Environment configuration

The configurations expects you to provide [Hiera version 4 configuration](https://docs.puppetlabs.com/puppet/latest/reference/lookup_quick.html#hierayaml-version-4-in-a-nutshell)
in environments. Example can be taken from [codingfuture/puppe-test](https://github.com/codingfuture/puppet-test/blob/master/hiera.yaml).

**NOTE1: there is a known closed bug in puppet <=4.3.2 - please make sure that all Hiera hierarchy files exist and both empty YAML and JSON files include '{}' at least**

## Global Hiera config

Due to a known open bug [PUP-5952](https://tickets.puppetlabs.com/browse/PUP-5952), global Hiera config hierarchy
must match environment's hierarchy. Meanwhile, this can be overridden by `$cfpuppetserver::puppetserver::global_hiera_config`

Thefore, current global config is:

```yaml
---
:backends:
  - yaml
:hierarchy:
  - "%{trusted.domain}/%{trusted.hostname}"
  - "%{trusted.domain}"
  - "%{facts.cf_location}/%{facts.cf_location_pool}"
  - "%{facts.cf_location}"
  - common
:merge_behavior: deeper
:yaml:
  # Make sure to use hiera.yaml in environments
  #:datadir: /etc/puppetlabs/code/hieradata
  # Per-environment hiera.yaml is still buggy
  :datadir: "/etc/puppetlabs/code/environments/%{::environment}/data"
```

### Adding new Puppet clients

This module also provides a handy tool to initalize new puppet client hosts:

```
~#  /root/genclientinit.sh 
Usage: ./genclientinit.sh <certname> [<cflocation> [<cflocationpool> [<http_proxy>]]
```

## Setup

### Initial Puppet Server infrastructure

Either do manually (preferred for self-education) or use bundled [setup script](https://github.com/codingfuture/puppet-cfpuppetserver/blob/master/setup_puppetserver.sh):
```
~# ./setup_puppetserver.sh
Usage: ./setup_puppetserver.sh <r10k_repo_url> [<certname=hostname> [<cflocation> [<cflocationpool> [<http_proxy=$http_proxy>] ] ] ]
```

### Config for Puppet Server node

If r10k is used until [RK-3](https://tickets.puppetlabs.com/browse/RK-3) is solved, make
sure to have the following lines in Puppetfile:

```ruby
# This deps are installed automatically by librarian-puppet, if cfpuppetserver is used
mod 'puppetlabs/stdlib', '4.11.0'
mod 'puppetlabs/apt', '2.2.1'
mod 'puppetlabs/postgresql', '4.7.1'
mod 'puppetlabs/puppetdb', '5.1.1'
mod 'codingfuture/cfnetwork'
mod 'codingfuture/cfsystem'
```

## Examples

Please check [codingufuture/puppet-test](https://github.com/codingfuture/puppet-test) for
example of a complete infrastructure configuration and Vagrant provisioning.


## `cfpuppetserver` class

* `puppet_host= $::trusted['certname']` - puppet server address
* `deployuser = 'deploypuppet'` - user name for auto deploy user for VCS hook
* `deployuser_auth_keys = undef` - list of ssh_authorized_keys configurations
* `repo_url = undef` - repository location in URI format (e.g. ssh://user@host/repo or file:///some/path)
* `puppetsever = true` - if true then assume Puppet Server lives on this host (affects firewall)
* `puppetdb = true` - if true then assume Puppet DB lives on this host (affects firewall)
* `puppetdb_port = 8081` - port to use for Puppet DB
* `setup_postgresql = true` - if true and $puppetdb == true then install and configure PostgreSQL as well
* `service_face = 'any'` - `cfnetwork::iface` name to listen for incoming client connections
* `puppetserver_mem = auto` - memory in MB to use for Puppet Server, if installed
* `puppetdb_mem = auto` - memory in MB to use for Puppet DB, if installed
* `postgresql_mem = auto` - memory in MB to use for PostgreSQL, if installed

## `cfpuppetserver::puppetdb` class

* `postgresql_host = 'localhost'` - PostgreSQL host to listen and connect
* `postgresql_port = 5432` - PostgreSQL port to listen and connect

## `cfpuppetserver::puppetserver` class

* `autosign = false` - DO NOT use in production. Enable auto-sign of client certificates.
* `global_hiera_config = 'cfpuppetserver/hiera.yaml'` - default global Hiera config


[cfnetwork]: https://github.com/codingfuture/puppet-cfnetwork
[cfsystem]: https://github.com/codingfuture/puppet-cfsystem
