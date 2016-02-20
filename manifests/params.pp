
class cfpuppetserver::params {
    include stdlib
    $mem_bytes = $::memory['system']['total_bytes']
    $mem_mb = $mem_bytes / 1024 / 1024
    $heap_mb = $mem_mb * 3 / 4 # reserve 25% of mem
    
    if is_bool($cfpuppetserver::puppetdb) and $cfpuppetserver::puppetdb {
        if $cfpuppetserver::puppetserver and $cfpuppetserver::setup_postgresql {
            $puppetdb_mem = $heap_mb / 3
            $puppetserver_mem = $puppetdb_mem
            $puppetsql_mem = $puppetdb_mem
        } elsif $cfpuppetserver::puppetserver {
            $puppetdb_mem = $heap_mb / 2
            $puppetserver_mem = $puppetdb_mem
            $puppetsql_mem = 0
        } elsif $cfpuppetserver::setup_postgresql {
            $puppetdb_mem = $heap_mb / 2
            $puppetserver_mem = 0
            $puppetsql_mem = $puppetdb_mem
        } else {
            $puppetdb_mem = $heap_mb
            $puppetserver_mem = 0
            $puppetsql_mem = 0
        }
    } else {
        # $puppetserver
        $puppetdb_mem = 0
        $puppetserver_mem = $heap_mb
        $puppetsql_mem = 0
    }
}