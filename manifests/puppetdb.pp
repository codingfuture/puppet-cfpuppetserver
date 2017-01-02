#
# Copyright 2016-2017 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver::puppetdb (
    $use_proxy = 'secure',
    $port = 8081,
    $max_connections = 30,
    $memory_weight = 100,
    $memory_max = 256,
    $cpu_weight = 100,
    $io_weight = 100,
    $cert_whitelist = undef,
    $settings_tune = {}
) {
    assert_private();

    $puppetdb = $cfpuppetserver::puppetdb

    cfnetwork::describe_service {'puppetdb': server => "tcp/${port}"}

    if is_bool($puppetdb) and $puppetdb {
        $service_name = 'cfpuppetdb'
        $cluster = $cfpuppetserver::cluster
        $database = $cfpuppetserver::database

        #---
        cfsystem_memory_weight { $service_name:
            ensure => present,
            weight => $memory_weight,
            min_mb => 128,
            max_mb => $memory_max,
        }

        cfsystem_memory_weight { "${service_name}/conns":
            ensure => present,
            weight => 0,
            min_mb => $max_connections,
        }

        # Firewall
        #---
        cfnetwork::service_port { 'local:puppetdb': }
        cfnetwork::client_port { 'local:puppetdb':
            user => ['root', 'puppet']
        }

        if $cfpuppetserver::allow_update_check {
            cfnetwork::client_port { 'any:http:puppetdb_version':
                user => ['puppetdb'],
                dst  => 'updates.puppetlabs.com'
            }
        }

        if !$cfpuppetserver::puppetserver {
            cfnetwork::service_port {
                "${cfpuppetserver::iface}:puppetdb":
                    src => $cfsystem::puppet_host
            }
        }

        $fqdn = $::fqdn

        if $cert_whitelist {
            $q_cert_whitelist = $cert_whitelist
        } elsif $cfpuppetserver::puppetserver {
            $q_cert_whitelist = [$fqdn]
        } else {
            $q_cert_whitelist = cf_query_resource(
                "Class['cfpuppetserver']{ puppetdb = '${fqdn}'}",
                "Class['cfpuppetserver::puppetserver']"
            ).reduce([]) |$m, $r| {
                $m << $r['certname']
            }
        }

        #---
        $rwaccess_name = "${service_name}rw"
        $roaccess_name = "${service_name}ro"

        cfdb::access{ $rwaccess_name:
            cluster         => $cluster,
            role            => $database,
            local_user      => 'puppetdb',
            max_connections => $max_connections,
            use_proxy       => $use_proxy,
            custom_config   => 'cfpuppetserver::internal::dbaccess',
            use_unix_socket => false,
            fallback_db     => $database,
        }
        cfdb::access{ $roaccess_name:
            cluster         => $cluster,
            # PDB-2842 - PDB should grant read-only access to different [read-database] user
            #role            => "${database}ro",
            role            => $database,
            local_user      => 'puppetdb',
            max_connections => $max_connections,
            use_proxy       => $use_proxy,
            custom_config   => 'cfpuppetserver::internal::dbaccess',
            config_prefix   => 'DBRO_',
            use_unix_socket => false,
            fallback_db     => $database,
            distribute_load => true,
        }

        if $cfpuppetserver::postgresql and !$::facts['cfdbaccess'][$cluster] and !$cfpuppetserver::is_secondary {
            Cfdb::Database["${cluster}/${database}"] -> Cfdb::Access[$rwaccess_name]
            Cfdb::Database["${cluster}/${database}"] -> Cfdb::Access[$roaccess_name]
            Cfdb::Role["${cluster}/${database}"] -> Cfdb::Access[$rwaccess_name]
            Cfdb::Role["${cluster}/${database}ro"] -> Cfdb::Access[$roaccess_name]
        }

        #---
        package{ 'puppetdb': } ->
        group{ 'puppetdb': } ->
        user{ 'puppetdb':
            home => '/opt/puppetlabs/server/data/puppetdb',
            gid  => 'puppetdb',
        } ->
        file{ '/var/lib/puppetdb/':
            ensure => directory,
            owner  => 'puppetdb',
            group  => 'puppetdb',
            mode   => '0700',
        } ->
        cfsystem::puppetpki{ $service_name:
            user    => 'puppetdb',
            pki_dir => '/etc/puppetlabs/puppetdb/pki/',
        } ->
        cfpuppetserver::internal::cfpuppetdb { $service_name: }

        if $cfpuppetserver::allow_update_check {
            cfnetwork::client_port { 'any:http:puppetdb_version':
                user => ['puppet'],
                dst  => 'updates.puppetlabs.com'
            }
        }
    } elsif $puppetdb {
        cfnetwork::client_port { 'any:puppetdb':
            user => ['root', 'puppet'],
            dst  => $puppetdb,
        }
    } else {
        fail('$puppetdb must be either true or a destination host')
    }
}
