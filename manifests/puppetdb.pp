
class cfpuppetserver::puppetdb (
    $postgresql_host = 'localhost',
    $postgresql_listen = $postgresql_host,
    $postgresql_port = 5432,
    $postgresql_user = 'puppetdb',
    $postgresql_pass = 'puppetdb',
    $postgresql_ssl  = false,
) {
    assert_private();
    
    $puppetdb = $cfpuppetserver::puppetdb
    $puppetserver = $cfpuppetserver::puppetserver
    $puppet_host = $cfsystem::puppet_host
    $setup_postgresql = $cfpuppetserver::setup_postgresql
    
    cfnetwork::describe_service {'puppetdb': server => "tcp/${cfpuppetserver::puppetdb_port}"}
    cfnetwork::describe_service {'puppetpsql': server => "tcp/${postgresql_port}"}

    if is_bool($puppetdb) and $puppetdb {
        # postgreSQL
        #---
        if $setup_postgresql {
            class { 'cfpuppetserver::puppetdb::postgresql':
                stage => 'setup'
            }
            
            cfnetwork::service_port { 'local:puppetpsql': }
            # non-local port must be whitelisted manually
        }

        if $postgresql_host == 'localhost' {
            cfnetwork::client_port { 'local:puppetpsql':
                user => ['root', 'puppetdb'] }
        } else {
            cfnetwork::client_port { 'any:puppetpsql':
                user => ['root', 'puppetdb'],
                dst  => $postgresql_host,
            }
        }
        
        if $postgresql_ssl {
            $jdbc_ssl_properties = join([
                '?ssl=true',
                'sslfactory=org.postgresql.ssl.jdbc4.LibPQFactory',
                'sslmode=verify-full',
                'sslrootcert=/etc/puppetlabs/puppetdb/ssl/ca.pem',
                ], '&')
        } else {
            $jdbc_ssl_properties = ''
        }

        # PuppetDB
        #---
        class { 'puppetdb::server':
            database_host       => $postgresql_host,
            database_port       => $postgresql_port,
            database_username   => $postgresql_user,
            database_password   => $postgresql_pass,
            jdbc_ssl_properties => $jdbc_ssl_properties,
            manage_firewall     => false,
            java_args           => {
                '-Xmx' => "${cfpuppetserver::act_puppetdb_mem}m",
                '-Xms' => "${cfpuppetserver::act_puppetdb_mem}m",
            },
        }
        
        # Firewall
        #---
        cfnetwork::service_port { 'local:puppetdb': }
        cfnetwork::client_port { 'local:puppetdb':
            user => ['root', 'puppet']
        }
        
        if !$puppetserver {
            cfnetwork::service_port {
                "${cfpuppetserver::service_face}:puppetdb":
                    src => $puppet_host
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