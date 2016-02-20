
class cfpuppetserver (
    $puppet_host,
    $deployuser = 'deploypuppet',
    $deployuser_auth_keys = undef,
    $puppet_git_host = undef,
    
    $puppetserver = true,
    $puppetdb = true,
    $setup_postgresql = true,
    
    $service_face = 'any',
    $puppetserver_mem = cfpuppetserver::params::puppetserver_mem,
    $puppetdb_mem = cfpuppetserver::params::puppetdb_mem,
    $puppetsql_mem = cfpuppetserver::params::puppetsql_mem,
) inherits cfpuppetserver::params {
    include stdlib
    include cfnetwork
    include cfsystem
    include cfpuppetserver::puppetdb
    include cfpuppetserver::puppetserver
    
    #---
    # cleanup old version
    file {'/root/initclient.sh': ensure => absent}

    file {'/root/genclientinit.sh':
        owner   => root,
        group   => root,
        mode    => '0750',
        content => epp('cfpuppetserver/genclientinit.sh.epp', {
            puppet_host => $puppet_host
        }),
    }
}