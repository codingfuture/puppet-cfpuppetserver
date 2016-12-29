#
# Copyright 2016 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver::postgresql(
    $settings_tune = {},
    $port = 5432,
    $node_id = undef,
    $password = undef,

    $memory_weight = 200,
    $memory_max = undef,
    $cpu_weight = 200,
    $io_weight = 200,
) {
    assert_private();

    if $cfpuppetserver::postgresql {
        $init_db_from = $::os['name'] ? {
            'Debian' => $::os['distro']['codename'] ? {
                'jessie' => '9.4:/var/lib/postgresql/9.4/main/',
                default => '9.5:/var/lib/postgresql/9.5/main/',
            },
            'Ubuntu' => $::os['distro']['codename'] ? {
                default => '9.5:/var/lib/postgresql/9.5/main/'
            },
            default => '',
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
            default_extensions => false,
            extensions2        => ['contrib'],
        } ->
        cfdb::instance{ $cfpuppetserver::cluster:
            type          => 'postgresql',
            is_cluster    => $cfpuppetserver::is_cluster,
            is_secondary  => $cfpuppetserver::is_secondary,
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
