
class cfpuppetserver::puppetserver (
    $autosign = false,
) {
    assert_private();

    $deployuser = $cfpuppetserver::deployuser
    $deployuser_auth_keys = $cfpuppetserver::deployuser_auth_keys
    $puppet_git_host = $cfpuppetserver::puppet_git_host_parsed

    if $cfpuppetserver::puppetserver {
        if is_bool($cfpuppetserver::puppetdb) {
            $puppetdb_host = $::trusted['certname']
        } else {
            $puppetdb_host = $cfpuppetserver::puppetdb
        }
        
        class { 'puppetdb::master::config':
            puppetdb_server => $puppetdb_host,
            puppetdb_port   => $cfpuppetserver::puppetdb_port,
            manage_config   => true,
        }

        file {'/etc/puppetlabs/puppet/puppet.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppet.conf.epp'),
        }
        file {'/etc/puppetlabs/code/hiera.yaml':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => file('cfpuppetserver/hiera.yaml'),
        }
        
        package { 'puppetserver': }
        package { 'puppet-agent': }
        cfnetwork::service_port { "${cfpuppetserver::service_face}:puppet": }
        cfnetwork::client_port { 'any:http:puppetforge': user => 'root' }
        cfnetwork::client_port { 'any:https:puppetforge': user => 'root' }
        
        $java_args="-Xms${cfpuppetserver::act_puppetserver_mem}m -Xmx${cfpuppetserver::act_puppetserver_mem}m"
        file_line { 'puppetsever_memlimit':
            ensure  => present,
            path    => '/etc/default/puppetserver',
            line    => "JAVA_ARGS=\"${java_args}\"",
            match   => 'JAVA_ARGS=',
            replace => true,
            notify  => Service['puppetserver'],
        }

        #======================================================================
        file {'/etc/puppetlabs/deploy.sh':
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => file('cfpuppetserver/deploy.sh'),
        }
        
        package {'r10k': provider => 'puppet_gem' }
        package {'deep_merge': provider => 'puppet_gem' }
        package {'activesupport': provider => 'puppet_gem' }
        package {'librarian-puppet':
            provider => 'puppet_gem',
            # wokraround for https://github.com/rodjek/librarian-puppet/issues/330
            require  => Package['activesupport'],
        }
        
        file {'/etc/puppetlabs/r10k/r10k.yaml':
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => epp('cfpuppetserver/r10k.yaml.epp'),
            require => Package['r10k'],
        }
        
        
        #======================================================================
        group { $deployuser: ensure => present }
        user { $deployuser:
            ensure         => present,
            groups         => ['ssh_access'],
            home           => "/home/${deployuser}",
            managehome     => true,
            purge_ssh_keys => true,
            membership     => inclusive,
            require        => Group['ssh_access'],
        }
        
        file {"/home/${deployuser}/puppetdeploy.sh":
            owner   => $deployuser,
            group   => $deployuser,
            mode    => '0750',
            content => "#!/bin/sh
sudo /etc/puppetlabs/deploy.sh
"
        }
        
        file {"/etc/sudoers.d/${deployuser}":
            group   => root,
            owner   => root,
            mode    => '0400',
            content => "
${deployuser} ALL=(ALL:ALL) NOPASSWD: /etc/puppetlabs/deploy.sh
",
        }
        
        if $deployuser_auth_keys {
            create_resources(
                ssh_authorized_key,
                prefix($deployuser_auth_keys, "${deployuser}@"),
                {
                    user => $deployuser,
                    'type' => 'ssh-rsa',
                    require => User[$deployuser],
                }
            )
        }
    
        if $puppet_git_host {
            cfnetwork::client_port { 'any:ssh:puppetvcs':
                dst     => $puppet_git_host,
                user    => 'root',
                comment => 'Puppet config git access'
            }
            cfnetwork::service_port { 'any:ssh:puppetvcs':
                src     => $puppet_git_host,
                comment => 'Puppet config git deploy access'
            }
        }
    }
}