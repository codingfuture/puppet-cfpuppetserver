
class cfpuppetserver::puppetdb (
    $postgresql_host = 'localhost',
    $postgresql_port = 5432,
) {
    assert_private();
    
    $puppetdb = $cfpuppetserver::puppetdb
    $puppetsever = $cfpuppetserver::puppetsever
    $puppet_host = $cfpuppetserver::puppet_host
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
        }

        if $postgresql_host == 'localhost' {
            cfnetwork::client_port { 'local:puppetpsql':
                user => ['root', 'puppetdb'] }
        }

        # PuppetDB
        #---
        class { 'puppetdb::server':
            database_host   => $postgresql_host,
            database_port   => $postgresql_port,
            manage_firewall => false,
            java_args       => {
                '-Xmx' => "${cfpuppetserver::act_puppetdb_mem}m",
                '-Xms' => "${cfpuppetserver::act_puppetdb_mem}m",
            },
        }
        
        cfnetwork::service_port { 'local:puppetdb': }
        cfnetwork::client_port { 'local:puppetdb':
            user => ['root', 'puppet'] }
        
        if !$puppetsever {
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