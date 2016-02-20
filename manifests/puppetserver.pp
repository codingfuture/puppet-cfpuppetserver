
class cfpuppetserver::puppetserver {
    $deployuser = $cfpuppetserver::deployuser
    $deployuser_auth_keys = $cfpuppetserver::deployuser_auth_keys
    $puppet_git_host = $cfpuppetserver::puppet_git_host

    if $cfpuppetserver::puppetserver {
        package { 'puppetserver': }
        service { 'puppetserver': ensure => running }
        cfnetwork::service_port { "${cfpuppetserver::service_face}:puppet": }
        cfnetwork::client_port { 'any:http:puppetforge': user => 'root' }
        cfnetwork::client_port { 'any:https:puppetforge': user => 'root' }
        
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

        $deploycmd = '/opt/puppetlabs/puppet/bin/r10k deploy environment -p'
        
        file {"/home/${deployuser}/puppetdeploy.sh":
            owner   => $deployuser,
            group   => $deployuser,
            mode    => '0750',
            content => "#!/bin/sh
sudo ${deploycmd}
"
        }
        
        file {"/etc/sudoers.d/${deployuser}":
            group   => root,
            owner   => root,
            mode    => '0400',
            content => "
${deployuser} ALL=(ALL:ALL) NOPASSWD: ${deploycmd}
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