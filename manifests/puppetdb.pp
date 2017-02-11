#
# Copyright 2016-2017 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver::puppetdb (
    Variant[Boolean, Enum['auto', 'secure', 'insecure']]
        $use_proxy = 'secure',
    Optional[Cfnetwork::Port]
        $port = 8081,
    Integer[1]
        $max_connections = 30,

    Integer[1]
        $memory_weight = 100,
    Optional[Integer[1]]
        $memory_max = 512,
    Cfsystem::CpuWeight
        $cpu_weight = 100,
    Cfsystem::IoWeight
        $io_weight = 100,

    Variant[String[1], Array[String[1]]]
        $cert_whitelist = [],
    Hash
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
            min_mb => 512,
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

        $puppetserver_hosts = unique(
            $cfpuppetserver::puppetserver_hosts +
            [$cfsystem::puppet_host] +
            ($cfpuppetserver::puppetserver ? {
                true  => [$::fqdn],
                false => [],
            }) +
            ($cfpuppetserver::autodiscovery ? {
                true  => cfsystem::query([
                    'from', 'resources', ['extract', [ 'certname' ],
                        ['and',
                            ['=', 'type', 'Cf_puppetserver'],
                        ],
                ]]).map |$v| { $v['certname'] },
                false => [],
            })
        )

        $q_cert_whitelist = unique(
            any2array($cert_whitelist) +
            $puppetserver_hosts
        )

        cfnetwork::ipset { 'cfpuppet_puppetserver':
            addr => $puppetserver_hosts,
        }

        cfnetwork::service_port {
            "${cfpuppetserver::iface}:puppetdb":
                src => 'ipset:cfpuppet_puppetserver'
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
        cfpuppetserver::internal::cfpuppetdb { $service_name:
            require => [
                Cfpuppetserver::Internal::Dbaccess[$rwaccess_name],
                Cfpuppetserver::Internal::Dbaccess[$roaccess_name],
            ]
        }

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
