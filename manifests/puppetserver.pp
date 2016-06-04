
class cfpuppetserver::puppetserver (
    $autosign = false,
    $global_hiera_config = 'cfpuppetserver/hiera.yaml',
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
            require => Package['puppetserver'],
        }
        file {'/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetserver.conf.epp'),
            require => Package['puppetserver'],
        }
        file {'/etc/puppetlabs/code/hiera.yaml':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => file($global_hiera_config),
            require => Package['puppetserver'],
            notify  => Service['puppetserver'],
        }
        
        file {'/etc/puppetlabs/code/hieradata':
            ensure  => directory,
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0755',
            require => Package['puppetserver'],
        }
        
        file {'/etc/puppetlabs/code/hieradata/global.yaml':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0755',
            replace => false,
            content => file('cfpuppetserver/global.yaml'),
            require => Package['puppetserver'],
            notify  => Service['puppetserver'],
        }
        
        package { 'puppetserver': }
        cfnetwork::service_port { "${cfpuppetserver::service_face}:puppet": }
        cfnetwork::client_port { 'any:http:puppetforge': user => 'root' }
        cfnetwork::client_port { 'any:https:puppetforge': user => 'root' }
        
        if $cfpuppetserver::allow_update_check {
            cfnetwork::client_port { 'any:http:puppetdb_version':
                user => ['puppet'],
                dst => 'updates.puppetlabs.com'
            }
            file {'/etc/puppetlabs/puppetserver/opt-out':
                ensure => absent
            }
        } else {
            file {'/etc/puppetlabs/puppetserver/opt-out':
                ensure  => file,
                content => '',
            }            
        }
        
        $java_args="-Xms${cfpuppetserver::act_puppetserver_mem}m -Xmx${cfpuppetserver::act_puppetserver_mem}m"
        file_line { 'puppetsever_memlimit':
            ensure  => present,
            path    => '/etc/default/puppetserver',
            line    => "JAVA_ARGS=\"${java_args}\"",
            match   => 'JAVA_ARGS=',
            replace => true,
            require => Package['puppetserver'],
            # This causes deploy failure compare to temporary PuppetDB unavailability
            #notify  => Service['puppetserver'],
        }
        
        if ! defined(Service['puppetserver']) {
            service { 'puppetserver':
                ensure  => running,
                require => Package['puppetserver'],
            }
        }

        #======================================================================
        file {"${cfsystem::custombin::bin_dir}/cf_r10k_deploy":
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => file('cfpuppetserver/deploy.sh'),
        }
        
        package {'r10k': provider => 'puppet_gem' }
        package {'activesupport': provider => 'puppet_gem' }
        package {'librarian-puppet':
            provider => 'puppet_gem',
            # wokraround for https://github.com/rodjek/librarian-puppet/issues/330
            require  => Package['activesupport'],
        }
        
        file {'/etc/puppetlabs/r10k':
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0750',
        }
        
        file {'/etc/puppetlabs/r10k/r10k.yaml':
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => epp('cfpuppetserver/r10k.yaml.epp'),
            require => Package['r10k'],
        }
        
        file_line {'ignore puppet environments':
                ensure => present,
                path   => '/etc/.gitignore',
                line   => 'puppetlabs/code/environments/*',
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
sudo ${cfsystem::custombin::bin_dir}/cf_r10k_deploy
"
        }
        
        file {"/etc/sudoers.d/${deployuser}":
            group   => root,
            owner   => root,
            mode    => '0400',
            content => "
${deployuser} ALL=(ALL:ALL) NOPASSWD: ${cfsystem::custombin::bin_dir}/cf_r10k_deploy
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
        
        #======================================================================
        $is_slave = $::trusted['certname'] != $cfsystem::puppet_host
        
        if $is_slave {
            file_line { 'remove_puppet_ca_enable':
                ensure  => present,
                path    => '/etc/puppetlabs/puppetserver/bootstrap.cfg',
                line    => '#puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
                match   => 'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
                replace => true,
            }
            file_line { 'add_puppet_ca_disable':
                ensure  => present,
                path    => '/etc/puppetlabs/puppetserver/bootstrap.cfg',
                line    => 'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
                match   => '#puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
                replace => true,
            }
            
            file { '/etc/puppetlabs/puppetserver/conf.d/webserver.conf':
                owner   => 'puppet',
                group   => 'puppet',
                mode    => '0644',
                content => epp('cfpuppetserver/webserver.conf.epp')
            }
        }
    }
}