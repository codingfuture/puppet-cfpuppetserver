#
# Copyright 2016-2017 (c) Andrey Galkin
#


# Please see README
class cfpuppetserver::puppetserver (
    Boolean
        $autosign = false,
    String[1]
        $global_hiera_config = 'cfpuppetserver/hiera.yaml',
    Integer[1]
        $memory_weight = 100,
    Optional[Integer[1]]
        $memory_max = undef,
    Integer[1,25600]
        $cpu_weight = 100,
    Integer[1,200]
        $io_weight = 100,
    String[1]
        $activesupport_ver = '4.2.7.1',
    Enum['off', 'warning', 'error'] $strict = 'warning',
    String[1] $disable_warnings = 'deprecations',
    Hash
        $settings_tune = {}
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
        $puppetdb_port = $cfpuppetserver::puppetdb::port

        $puppetdb_static_hosts = $cfpuppetserver::puppetdb_hosts +
            ($cfpuppetserver::puppetdb ? {
                true    => [$::fqdn],
                default => []
            })

        if $cfpuppetserver::autodiscovery {
            $puppetdb_dynamic_hosts = cf_query_resources(
                false,
                "Cf_puppetdb[${cfpuppetserver::puppetdb::service_name}]",
                false,
            ).reduce([]) |$m, $v| {
                $host_name = $v['certname']
                $host_port = $v['parameters']['port']

                if $host_port == $puppetdb_port {
                    $m << $host_name
                } else {
                    notice { "cfpuppetserver:${host_name}":
                        message  => "Port mismatch ${host_port} != ${puppetdb_port} for ${host_name}",
                        loglevel => 'err',
                    }
                }
            }
        }else {
            $puppetdb_dynamic_hosts = []
        }

        $puppetdb_hosts = unique($puppetdb_static_hosts + $puppetdb_dynamic_hosts)

        if empty($puppetdb_hosts) {
            fail('No PuppetDB hosts are known!')
        }

        cfnetwork::ipset { 'cfpuppet_puppetdb':
            addr => $puppetdb_hosts,
        }

        cfnetwork::client_port { 'any:puppetdb':
            user => ['root', 'puppet'],
            dst  => 'ipset:cfpuppet_puppetdb',
        }

        #---
        # if there is local PuppetDB, query only that
        if $cfpuppetserver::puppetdb {
            $server_urls = [$::fqdn]
            $submit_only_server_urls = $puppetdb_hosts - $::fqdn
        } else {
            $server_urls = $puppetdb_hosts
            $submit_only_server_urls = []
        }

        $service_name = 'cfpuppetserver'
        $conf_dir = '/etc/puppetlabs/puppetserver/conf.d'

        cfsystem_memory_weight { $service_name:
            ensure => present,
            weight => $memory_weight,
            min_mb => 512,
            max_mb => $memory_max,
        }

        package { 'puppetserver': } ->
        package { 'puppetdb-termini': } ->
        file {'/etc/puppetlabs/puppet/puppetdb.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetdb.conf.epp', {
                server_urls             => $server_urls.map |$host| {
                    "https://${host}:${puppetdb_port}"
                },
                submit_only_server_urls => $submit_only_server_urls.map |$host| {
                    "https://${host}:${puppetdb_port}"
                },
            }),
        } ->
        file {'/etc/puppetlabs/puppet/puppet.conf':
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppet.conf.epp'),
        } ->
        file { "${conf_dir}/auth.conf":
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetserver/auth.conf.epp')
        } ->
        file { "${conf_dir}/puppetserver.conf":
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetserver/puppetserver.conf.epp', {
                settings_tune => pick($settings_tune['puppetserver'], {}),
            }),
        } ->
        file { "${conf_dir}/webserver.conf":
            owner   => 'puppet',
            group   => 'puppet',
            mode    => '0644',
            content => epp('cfpuppetserver/puppetserver/webserver.conf.epp')
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
            require      => Anchor['cfnetwork:firewall'],
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
        $cf_puppetserver_reload = "${cfsystem::custombin::bin_dir}/cf_puppetserver_reload"
        file { $cf_puppetserver_reload:
            owner   => 'root',
            group   => 'puppet',
            mode    => '0750',
            content => epp('cfpuppetserver/cf_puppetserver_reload.epp')
        } ->
        cfnetwork::client_port { 'local:puppet:reload':
            dst  => $::fqdn,
            user => 'puppet',
        } ->
        Cf_puppetserver[$service_name]

        #======================================================================
        $cf_r10k_deploy = "${cfsystem::custombin::bin_dir}/cf_r10k_deploy"

        file { $cf_r10k_deploy:
            owner   => 'root',
            group   => 'root',
            mode    => '0750',
            content => epp('cfpuppetserver/deploy.sh.epp'),
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
sudo ${cf_r10k_deploy}
"
        }

        cfauth::sudoentry { $deployuser:
            command => $cf_r10k_deploy,
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
    }
}
