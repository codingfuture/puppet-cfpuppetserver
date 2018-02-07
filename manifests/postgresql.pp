#
# Copyright 2016-2018 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver::postgresql(
    Hash
        $settings_tune = {},
    Cfnetwork::Port
        $port = 5432,
    Optional[Integer]
        $node_id = undef,
    Optional[String[1]]
        $password = undef,
    Optional[String[1]]
        $version = undef,

    Integer[1]
        $memory_weight = 100,
    Optional[Integer[1]]
        $memory_max = undef,
    Cfsystem::CpuWeight
        $cpu_weight = 200,
    Cfsystem::IoWeight
        $io_weight = 200,
) {
    assert_private();

    if $cfpuppetserver::postgresql {
        # TODO: change to use true fact with fallback to these hardcoded values
        $psql_version = $::facts['operatingsystem'] ? {
            'Debian' => $::facts['operatingsystemrelease'] ? {
                '8'     => '9.4',
                '9'     => '9.6',
                default => '9.6',
            },
            'Ubuntu' => $::facts['operatingsystemrelease'] ? {
                '15.10' => '9.4',
                '16.04' => '9.5',
                '16.10' => '9.5',
                '17.04' => '9.6',
                default => '9.6',
            },
            default  => undef
        }

        $init_db_from = empty($psql_version) ? {
            true    => '',
            default => "${psql_version}:/var/lib/postgresql/${psql_version}/main/"
        }

        $cfdb_settings = {
            secure_cluster => true,
            node_id => $node_id,
            init_db_from => $init_db_from,
        }

        $databases = $cfpuppetserver::is_secondary ? {
            false   => {
                "${cfpuppetserver::database}" => {
                    roles => {
                        ro => {
                            readonly => true,
                        }
                    },
                    ext   => ['pg_trgm'],
                }
            },
            default => undef,
        }

        class { 'cfdb::postgresql':
            version            => $version,
            default_extensions => false,
            extensions2        => ['contrib'],
        }
        -> cfdb::instance{ $cfpuppetserver::cluster:
            type          => 'postgresql',
            is_cluster    => $cfpuppetserver::is_cluster,
            is_secondary  => $cfpuppetserver::is_secondary,
            is_arbitrator => $cfpuppetserver::is_arbitrator,
            iface         => $cfpuppetserver::iface,
            port          => $port,
            settings_tune => merge($settings_tune, {
                cfdb => $cfdb_settings,
            }),
            databases     => $databases,
            memory_weight => $memory_weight,
            memory_max    => $memory_max,
            cpu_weight    => $cpu_weight,
            io_weight     => $io_weight,
        }
    }
}
