
class cfpuppetserver::puppetdb (
    $puppetdb_port = 8081,
    $postgresql_host = '127.0.0.1',
    $postgresql_port = 5432,
) {
    $puppetdb = $cfpuppetserver::puppetdb
    $puppetsever = $cfpuppetserver::puppetsever
    $puppet_host = $cfpuppetserver::puppet_host
    $setup_postgresql = $cfpuppetserver::setup_postgresql
    
    cfnetwork::describe_service {'puppetdb': server => "tcp/${puppetdb_port}"}
    cfnetwork::describe_service {'puppetpsql': server => "tcp/${postgresql_port}"}

    if is_bool($puppetdb) and $puppetdb {
        # postgreSQL
        #---
        if $setup_postgresql {
            class { 'puppetdb::database::postgresql':
                listen_addresses => $postgresql_host,
                database_port    => $postgresql_port,
                manage_firewall  => false,
            }
            
            postgresql::server::config_entry { 'shared_buffers':
                value => "${cfpuppetserver::puppetsql_mem}MB",
            }

            cfnetwork::service_port { 'local:puppetpsql': }
        }

        if $postgresql_host == '127.0.0.1' {
            cfnetwork::client_port { 'local:puppetpsql': user => 'puppetdb' }
        }

        # PuppetDB
        #---
        class { 'puppetdb::server':
            database_host   => $postgresql_host,
            database_port   => $postgresql_port,
            manage_firewall => false,
            java_args       => {
                '-Xmx' => "${cfpuppetserver::puppetdb_mem}m",
                '-Xms' => "${cfpuppetserver::puppetdb_mem}m",
            },
        }
        
        cfnetwork::service_port { 'local:puppetdb': }
        cfnetwork::client_port { 'local:puppetdb': user => 'puppet' }
        
        if !$puppetsever {
            cfnetwork::service_port {
                "${cfpuppetserver::service_face}:puppetdb":
                    src => $puppet_host
            }
        }
    } elsif $puppetdb {
        cfnetwork::client_port { 'any:puppetdb':
            user => 'puppet',
            dst  => $puppetdb,
        }
    } else {
        fail('$puppetdb must be either true or a destination host')
    }
}