
class cfpuppetserver (
    $deployuser = 'deploypuppet',
    $deployuser_auth_keys = undef,
    $repo_url = undef,
    
    $puppetserver = true,
    $puppetdb = true,
    $puppetdb_port = 8081,
    $setup_postgresql = true,
    
    $service_face = 'any',
    $puppetserver_mem = undef,
    $puppetdb_mem = undef,
    $postgresql_mem = undef,
    
    $allow_update_check = false,
    
    # deprecated
    $puppet_git_host = undef,
) {
    include stdlib
    include cfnetwork
    include cfsystem
    include cfsystem::custombin
    
    #---
    if $puppet_git_host {
        warning( '$puppet_git_host is deprecated, use $repo_url')
        $puppet_git_host_parsed = $puppet_git_host
    }
    
    if $repo_url {
        $repo_url_parsed = cfpuppetserver_uriparse($repo_url)
        
        if $repo_url_parsed {
            $puppet_git_host_parsed = $repo_url_parsed['host']
        } else {
            fail("Failed to parse \$repo_url='${repo_url}'")
        }
    }
    
    
    #---
    $mem_bytes = $::memory['system']['total_bytes']
    $mem_mb = $mem_bytes / 1024 / 1024
    $heap_mb = $mem_mb * 3 / 4 # reserve 25% of mem
    
    if is_bool($puppetdb) and $puppetdb {
        if $puppetserver and $setup_postgresql {
            $def_puppetdb_mem = $heap_mb / 3
            $def_puppetserver_mem = $def_puppetdb_mem * 2 / 3
            $def_postgresql_mem = $def_puppetdb_mem
        } elsif $puppetserver {
            $def_puppetdb_mem = $heap_mb / 2
            $def_puppetserver_mem = $def_puppetdb_mem * 2 / 3
            $def_postgresql_mem = 0
        } elsif $setup_postgresql {
            $def_puppetdb_mem = $heap_mb / 2
            $def_puppetserver_mem = 0
            $def_postgresql_mem = $def_puppetdb_mem
        } else {
            $def_puppetdb_mem = $heap_mb
            $def_puppetserver_mem = 0
            $def_postgresql_mem = 0
        }
    } elsif $puppetserver {
        $def_puppetdb_mem = 0
        $def_puppetserver_mem = $heap_mb
        $def_postgresql_mem = 0
    } else {
        fail( 'At least one of $puppetserver or $puppetdb must be true' )
    }
    
    $act_puppetserver_mem = pick($puppetserver_mem, $def_puppetdb_mem)
    $act_puppetdb_mem = pick($puppetdb_mem, $def_puppetserver_mem)
    $act_postgresql_mem = pick($postgresql_mem, $def_postgresql_mem)
    
    if $act_puppetserver_mem < 192 and $act_puppetserver_mem != 0 {
        fail("Puppet server requires minimum of 192MB of RAM, configured: ${act_puppetserver_mem}")
    }
    if $act_puppetdb_mem < 192 and $act_puppetdb_mem != 0 {
        fail("Puppet server requires minimum of 192MB of RAM, configured: ${act_puppetdb_mem}")
    }
    if $act_postgresql_mem < 128 and $act_postgresql_mem != 0 {
        fail("Puppet server requires minimum of 128MB of RAM, configured: ${act_postgresql_mem}")
    }

    include cfpuppetserver::puppetdb
    include cfpuppetserver::puppetserver
    
    #---
    file {"${cfsystem::custombin::bin_dir}/cf_gen_puppet_client_init":
        owner   => root,
        group   => root,
        mode    => '0750',
        content => epp('cfpuppetserver/genclientinit.sh.epp', {
            puppet_host => $cfsystem::puppet_host
        }),
    }
}