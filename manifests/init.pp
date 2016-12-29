#
# Copyright 2016 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver (
    $deployuser = 'deploypuppet',
    $deployuser_auth_keys = undef,
    $repo_url = undef,

    $puppetserver = true,
    $puppetdb = true,
    $postgresql = true,

    $iface = 'any',
    $cluster = 'cfpuppet',
    $database = 'puppetdb',
    $is_cluster = false,
    $is_secondary = false,
    $allow_update_check = false,
) {
    include stdlib
    include cfnetwork
    include cfsystem
    include cfsystem::custombin

    #---
    include cfpuppetserver::postgresql
    include cfpuppetserver::puppetdb
    include cfpuppetserver::puppetserver

    class { 'cfpuppetserver::internal::services':
        stage => 'deploy',
    }

    #---
    file {"${cfsystem::custombin::bin_dir}/cf_gen_puppet_client_init":
        owner   => root,
        group   => root,
        mode    => '0750',
        content => epp('cfpuppetserver/genclientinit.sh.epp', {
            puppet_host => $cfsystem::puppet_host
        }),
    }
}
