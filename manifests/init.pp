
class cfpuppetserver (
    $puppet_host,
    $deployuser = 'deploypuppet',
    $deployuser_auth_keys = undef,
    $puppet_git_host = undef,
    $puppetsever = true,
    $puppetdb = true,
    $service_face = 'any',
) {
    include stdlib
    include cfnetwork
    include cfsystem
    cfnetwork::describe_service {'puppetdb': server => 'tcp/8081'}
    cfnetwork::describe_service {'puppetpsql': server => 'tcp/5432'}

    if is_bool($puppetdb) and $puppetdb {
        $have_puppetdb = true
        package { 'postgresql': }
        service { 'postgresql': ensure => running }
        package { 'puppetdb': }
        service { 'puppetdb': ensure => running }
        
        cfnetwork::service_port { 'local:puppetpsql': }
        cfnetwork::service_port { 'local:puppetdb': }
        cfnetwork::client_port { 'local:puppetdb': user => 'puppet' }
        cfnetwork::client_port { 'local:puppetpsql': user => 'puppetdb' }
        
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

    if $puppetsever {
        $have_puppetserver = true
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
    
    #---
    # cleanup old version
    file {'/root/initclient.sh': ensure => absent}

    file {'/root/genclientinit.sh':
        owner   => root,
        group   => root,
        mode    => '0750',
        content => epp('cfpuppetserver/genclientinit.sh.epp', {
            puppet_host => $puppet_host
        }),
    }
}