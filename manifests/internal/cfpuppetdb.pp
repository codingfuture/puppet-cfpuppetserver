#
# Copyright 2016-2017 (c) Andrey Galkin
#


# Please see README
define cfpuppetserver::internal::cfpuppetdb {
    assert_private();

    $service_name = $cfpuppetserver::puppetdb::service_name

    $settings_tune = merge($cfpuppetserver::puppetdb::settings_tune, {
        'puppetdb' => merge(pick_default($cfpuppetserver::puppetdb::settings_tune['puppetdb'], {}), {
            'disable-update-checking' => $cfpuppetserver::allow_update_check ? {
                false   => strip('true '),
                default => strip('false '),
            }
        }),
        'jetty'    => merge(pick_default($cfpuppetserver::puppetdb::settings_tune['jetty'], {}), {
            'ssl-port' => $cfpuppetserver::puppetdb::port,
        }),
    })

    cf_puppetdb{ $service_name:
        ensure         => present,
        service_name   => $service_name,
        cpu_weight     => $cfpuppetserver::puppetdb::cpu_weight,
        io_weight      => $cfpuppetserver::puppetdb::io_weight,
        dbaccess       => getparam(Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::rwaccess_name], 'config_vars'),
        rodbaccess     => getparam(Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::roaccess_name], 'config_vars'),
        port           => $cfpuppetserver::puppetdb::port,
        cert_whitelist => $cfpuppetserver::puppetdb::q_cert_whitelist,
        settings_tune  => $settings_tune,
        require        => [
            Cfdb::Access[$cfpuppetserver::puppetdb::rwaccess_name],
            Cfdb::Access[$cfpuppetserver::puppetdb::roaccess_name],
            Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::rwaccess_name],
            Cfpuppetserver::Internal::Dbaccess[$cfpuppetserver::puppetdb::roaccess_name],
        ]
    }
}
