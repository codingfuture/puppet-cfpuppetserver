# cfpuppetserver

## Description

Functionality of this package is not complete. It's primary purpose is to live in peace
with [cfsystem][] and [cfnetwork][] packages.

However, it also provides a handy tool to initalize new puppet client hosts:

```
~#  /root/genclientinit.sh 
Usage: ./genclientinit.sh <certname> [<cflocation> [<cflocationpool> [<http_proxy>]]
```

## Setup

If r10k is used until [RK-3](https://tickets.puppetlabs.com/browse/RK-3) is solved, make
sure to have the following lines in Puppetfile:

```ruby
mod 'puppetlabs/stdlib', '4.11.0'
mod 'puppetlabs/apt', '2.2.1'
mod 'codingfuture/cfnetwork'
mod 'codingfuture/cfsystem'
```

## `cfpuppetserver` class

* `puppet_host` - puppet server address
* `deployuser = 'deploypuppet'` - user name for auto deploy user for VCS hook
* `deployuser_auth_keys = undef` - list of ssh_authorized_keys configurations
* `puppet_git_host = undef` - if set, adds require firewall rules to deploy from VCS
* `puppetsever = true` - if true, assume Puppet Server lives on this host (affects firewall)
* `puppetdb = true` - if true, assume Puppet DB lives on this host (affects firewall)
* `service_face = 'any'` - `cfnetwork::iface` name to listen for incoming client connections


[cfnetwork]: https://github.com/codingfuture/puppet-cfnetwork
[cfsystem]: https://github.com/codingfuture/puppet-cfsystem
