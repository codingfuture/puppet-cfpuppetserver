
# Please see README
class cfpuppetserver::puppetserver (
    $autosign = false,
    $global_hiera_config = 'cfpuppetserver/hiera.yaml',
    $memory_weight = 100,
    $memory_max = undef,
    $cpu_weight = 100,
    $io_weight = 100,
    $activesupport_ver = '4.2.7.1',
    ENUM['off', 'warning', 'error'] $strict = 'warning',
    String[1] $disable_warnings = 'deprecations',
) {
    assert_private();

    #---
    if $cfpuppetserver::repo_url {
        $repo_url_parsed = cfpuppetserver_uriparse($cfpuppetserver::repo_url)

        if $repo_url_parsed {
            $puppet_git_host_parsed = $repo_url_parsed['host']
        } else {
            fail("Failed to parse \$repo_url='${cfpuppetserver::repo_url}'")
        }
    }


    $deployuser = $cfpuppetserver::deployuser
    $deployuser_auth_keys = $cfpuppetserver::deployuser_auth_keys
    $puppet_git_host = $puppet_git_host_parsed

    if $cfpuppetserver::puppetserver {
        if is_bool($cfpuppetserver::puppetdb) {
            $puppetdb_host = [$::fqdn]
        } else {
            $puppetdb_host = any2array($cfpuppetserver::puppetdb)
        }

        $puppetdb_port = $cfpuppetserver::puppetdb::port

        $puppetdb_server_urls = ($puppetdb_host.reduce([]) |$m, $host| {
            $m << "https://${host}:${puppetdb_port}"
        }).join(',')

        $service_name = 'cfpuppetserver'

        cfsystem_memory_weight { $service_name:
            ensure => present,
            weight => $memory_weight,
            min_mb => 192,
            max_mb => $memory_max,
        }

        package { 'puppetserver': } ->
        package { 'puppetdb-termini': } ->
        file {'/etc/puppetlabs/puppet/puppetdb.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetdb.conf.epp', {
                server_urls => $puppetdb_server_urls,
            }),
        } ->
        file {'/etc/puppetlabs/puppet/puppet.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppet.conf.epp'),
        } ->
        file {'/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetserver.conf.epp'),
        } ->
        file {'/etc/puppetlabs/code/hiera.yaml':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => file($global_hiera_config),
        } ->
        file {'/etc/puppetlabs/code/hieradata':
            ensure => directory,
            owner  => 'puppet',
            group  => 'puppet',
            mode   => '0755',
        } ->
        file {'/etc/puppetlabs/code/hieradata/global.yaml':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0755',
            replace => false,
            content => file('cfpuppetserver/global.yaml'),
        } ->
        cf_puppetserver{ $service_name:
            ensure       => present,
            service_name => $service_name,
            cpu_weight   => $cpu_weight,
            io_weight    => $io_weight,
        }

        cfnetwork::service_port { "${cfpuppetserver::iface}:puppet": }
        cfnetwork::client_port { 'any:http:puppetforge': user => 'root' }
        cfnetwork::client_port { 'any:https:puppetforge': user => 'root' }

        if $cfpuppetserver::allow_update_check {
            cfnetwork::client_port { 'any:http:puppetdb_version':
                user => ['puppet'],
                dst  => 'updates.puppetlabs.com'
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

        #======================================================================
        file {"${cfsystem::custombin::bin_dir}/cf_r10k_deploy":
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => file('cfpuppetserver/deploy.sh'),
        }

        package {'r10k': provider => 'puppet_gem' }
        package {'activesupport':
            ensure   => $activesupport_ver,
            provider => 'puppet_gem',
        }
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
        $is_slave = $::fqdn != $cfsystem::puppet_host

        file { '/etc/puppetlabs/puppetserver/services.d':
            ensure => directory,
            owner  => 'puppet',
            group  => 'puppet',
        }

        if $is_slave {
            file { '/etc/puppetlabs/puppetserver/services.d/ca.cfg':
                content => [
                    '# puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
                    'puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
                ].join("\n"),
            }
        } else {
            file { '/etc/puppetlabs/puppetserver/services.d/ca.cfg':
                content => [
                    'puppetlabs.services.ca.certificate-authority-service/certificate-authority-service',
                    '# puppetlabs.services.ca.certificate-authority-disabled-service/certificate-authority-disabled-service',
                ].join("\n"),
            }
        }

        file { '/etc/puppetlabs/puppetserver/conf.d/webserver.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/webserver.conf.epp')
        }
    }
}