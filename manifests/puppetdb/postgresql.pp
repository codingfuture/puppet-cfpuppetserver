class cfpuppetserver::puppetdb::postgresql {
    class { 'puppetdb::database::postgresql':
        listen_addresses => "${cfpuppetserver::puppetdb::postgresql_host}",
        database_port    => $cfpuppetserver::puppetdb::postgresql_port,
    }

    # Just to resolve cycle deps
    class { 'postgresql::client': }
    
    postgresql::server::config_entry { 'shared_buffers':
        value => "${cfpuppetserver::act_puppetsql_mem}MB",
    }
}
