#
# Copyright 2016-2019 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver (
    String[1]
        $deployuser = 'deploypuppet',
    Optional[Hash]
        $deployuser_auth_keys = undef,
    Optional[String[1]]
        $repo_url = undef,

    Boolean
        $puppetserver = true,
    Boolean
        $puppetdb = true,
    Boolean
        $postgresql = true,

    Boolean
        $autodiscovery = true,
    Variant[String[1], Array[String[1]]]
        $puppetdb_hosts = [],
    Variant[String[1], Array[String[1]]]
        $puppetserver_hosts = [],
    Variant[String[1], Array[String[1]]]
        $client_hosts = [], # hosts to whitelist for SSH access

    String[1]
        $iface = 'any',
    String[1]
        $cluster = 'cfpuppet',
    String[1]
        $database = 'puppetdb',
    Boolean
        $is_cluster = false,
    Boolean
        $is_secondary = false,
    Boolean
        $is_arbitrator = false,
    Boolean
        $allow_update_check = false,
) {
    include stdlib
    include cfnetwork
    include cfsystem
    include cfsystem::custombin

    #---
    $jre = 'openjdk-8-jre-headless'
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
