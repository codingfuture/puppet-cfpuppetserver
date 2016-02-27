class cfpuppetserver::puppetdb::postgresql {
    class { 'puppetdb::database::postgresql':
        listen_addresses    => $cfpuppetserver::puppetdb::postgresql_listen,
        database_port       => $cfpuppetserver::puppetdb::postgresql_port,
        database_username   => $cfpuppetserver::puppetdb::postgresql_user,
        database_password   => $cfpuppetserver::puppetdb::postgresql_pass,
        manage_package_repo => false,
    }

    # Just to resolve cycle deps
    class { 'postgresql::client': }
    
    postgresql::server::config_entry { 'shared_buffers':
        value => "${cfpuppetserver::act_postgresql_mem}MB",
    }
    
    file {'/etc/postgresql/ssl':
        ensure => directory,
        mode   => '0700',
        owner  => 'postgres',
        group  => 'postgres',
    } ->
    file {'/etc/postgresql/ssl/server.key':
        mode   => '0600',
        owner  => 'postgres',
        group  => 'postgres',
        source => "/etc/puppetlabs/puppet/ssl/private_keys/${::trusted['certname']}.pem",
    } ->
    file {'/etc/postgresql/ssl/server.crt':
        mode   => '0600',
        owner  => 'postgres',
        group  => 'postgres',
        source => "/etc/puppetlabs/puppet/ssl/certs/${::trusted['certname']}.pem",
    } ->
    file {'/etc/postgresql/ssl/ca.crt':
        mode   => '0600',
        owner  => 'postgres',
        group  => 'postgres',
        source => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
    } ->
    file {'/etc/postgresql/ssl/crl.crt':
        mode   => '0600',
        owner  => 'postgres',
        group  => 'postgres',
        source => '/etc/puppetlabs/puppet/ssl/crl.pem',
    } ->
    postgresql::server::config_entry {
        'ssl_key_file': value => '/etc/postgresql/ssl/server.key'
    } ->
    postgresql::server::config_entry {
        'ssl_cert_file': value => '/etc/postgresql/ssl/server.crt'
    } ->
    postgresql::server::config_entry {
        'ssl_ca_file': value => '/etc/postgresql/ssl/ca.crt'
    } ->
    postgresql::server::config_entry {
        'ssl_crl_file': value => '/etc/postgresql/ssl/crl.crt'
    } ->
    postgresql::server::config_entry {
        'ssl': value => true
    } ->
    postgresql::server::config_entry {
        'ssl_ciphers': value => 'HIGH'
    }
    
    if !defined(Service['postgresql']) {
        service { 'postgresql':
            ensure => running,
        }
    }
}
