
define cfpuppetserver::internal::cfpuppetdb {
    assert_private();
    
    $service_name = $cfpuppetserver::puppetdb::service_name
    
    cf_puppetdb{ $service_name:
        ensure         => present,
        service_name   => $service_name,
        cpu_weight     => $cfpuppetserver::puppetdb::cpu_weight,
        io_weight      => $cfpuppetserver::puppetdb::io_weight,
        dbaccess       => getparam(Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::rwaccess_name], 'config_vars'),
        rodbaccess     => getparam(Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::roaccess_name], 'config_vars'),
        port           => $cfpuppetserver::puppetdb::port,
        cert_whitelist => $cfpuppetserver::puppetdb::q_cert_whitelist,
        settings_tune  => merge($cfpuppetserver::puppetdb::settings_tune, {
            'puppetdb' => merge(pick_default($cfpuppetserver::puppetdb::settings_tune['puppetdb'], {}), {
                'disable-update-checking' => $cfpuppetserver::allow_update_check ? {
                    false   => 'true',
                    default => 'false',
                }
            }),
            'jetty' => merge(pick_default($cfpuppetserver::puppetdb::settings_tune['jetty'], {}), {
                'ssl-port' => $cfpuppetserver::puppetdb::port,
            }),
        }),
        require        => [
            Cfdb::Access[$cfpuppetserver::puppetdb::rwaccess_name],
            Cfdb::Access[$cfpuppetserver::puppetdb::roaccess_name],
            Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::rwaccess_name],
            Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::roaccess_name],
        ]
    }
}
