#
# Copyright 2016-2019 (c) Andrey Galkin
#


require File.expand_path( '../../../../puppet_x/cf_puppet_server', __FILE__ )


Puppet::Type.type(:cf_puppetdb).provide(
    :cfprov,
    :parent => PuppetX::CfPuppetServer::ProviderBase
) do
    desc "Provider for cfdb_access"
    
    commands :sudo => PuppetX::CfSystem::SUDO
    commands :systemctl => PuppetX::CfSystem::SYSTEMD_CTL
    commands :df => '/bin/df'
    
    def self.get_config_index
        'cf20puppet1db'
    end

    def self.get_generator_version
        cf_system().makeVersion(__FILE__)
    end
    
    def self.check_exists(params)
        debug('check_exists')
        begin
            systemctl(['status', "#{params[:service_name]}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end    
    
    def self.disk_size(dir)
        ret = df('-BM', '--output=size', dir)
        ret = ret.split("\n")
        ret[1].strip().to_i
    end

    def self.on_config_change(newconf)
        debug('on_config_change')
        
        newconf = newconf[newconf.keys[0]]
        service_name = newconf[:service_name]
        user = 'puppetdb'
        port = newconf[:port]
        dbaccess = newconf[:dbaccess]
        rodbaccess = newconf[:rodbaccess]
        cert_whitelist = newconf[:cert_whitelist]
        settings_tune = newconf[:settings_tune]
        cfdb_settings = settings_tune.fetch('cfdb', {})
        
        conf_root_dir = '/etc/puppetlabs/puppetdb'
        conf_dir = "#{conf_root_dir}/conf.d/"
        var_dir = '/var/lib/puppetdb/'
        pki_dir = "#{conf_root_dir}/pki/puppet"
        
        var_size = disk_size(var_dir)
        
        avail_mem = cf_system.getMemory(service_name)
        
        if is_jvm_metaspace
            meta_mem = (avail_mem * 0.2).to_i
            meta_mem = cf_system.fitRange(256, avail_mem, meta_mem)
            meta_param = 'MetaspaceSize'
        else
            meta_mem = (avail_mem * 0.05).to_i
            meta_mem = cf_system.fitRange(256, avail_mem, meta_mem)
            meta_param = 'PermSize'
        end
        
        heap_mem = ((avail_mem - meta_mem) * 0.95).to_i
        
        conf = {
            'global' => {
                'vardir' => var_dir,
                'logging-config' => "#{conf_root_dir}/logback.xml",
                #'update-server' => 'http://updates.puppetlabs.com/check-for-updates',
            },
            'puppetdb' => {
                #'certificate-whitelist' => '',
                #'historical-catalogs-limit' => '',
                #'disable-update-checking' => 'false',
            },
            'database' => {
                #'classname' => 'org.postgresql.Driver',
                #'subprotocol' => 'postgresql',
                'subname' => "//#{dbaccess['host']}:#{dbaccess['port']}/#{dbaccess['db']}",
                'username' => dbaccess['user'],
                'password' => dbaccess['pass'],
                'gc-interval' => 60,
                'dlo-compression-interval' => 60,
                'node-ttl' => '0s',
                'node-purge-ttl' =>'0s',
                'report-ttl' => '14d',
                'maximum-pool-size' => dbaccess['maxconn'].to_i,
                #'conn-max-age' => 5000,
                #'conn-lifetime' => 60000,
                #'connection-timeout' => 3000,
            },
            'read-database' => {
                #'classname' => 'org.postgresql.Driver',
                #'subprotocol' => 'postgresql',
                'subname' => "//#{rodbaccess['host']}:#{rodbaccess['port']}/#{rodbaccess['db']}",
                'username' => rodbaccess['user'],
                'password' => rodbaccess['pass'],
                'maximum-pool-size' => rodbaccess['maxconn'],
                #'conn-max-age' => 5000,
                #'conn-lifetime' => 60000,
                #'connection-timeout' => 3000,
            },
            'command-processing' => {
                #'threads' => ,
                #'dlo-compression-threshold' => ,
                #'store-usage' => (var_size * 0.5).to_i,
                #'temp-usage' => (var_size * 0.3).to_i,
                #'memory-usage' => (avail_mem * 0.1).to_i,
                #'max-frame-size' => '',
                #'reject-large-commands' => 'false',
                #'max-command-size' => '',
            },
            'jetty' => {
                #'host'
                #'port'
                #'max-threads'
                'ssl-host' => '0.0.0.0',
                'ssl-port' => 8081,
                'ssl-cert' => "#{pki_dir}/local.crt",
                'ssl-key' => "#{pki_dir}/local.key",
                'ssl-ca-cert' => "#{pki_dir}/ca.crt",
                #'ssl-protocols'
                'ssl-crl-path' => "#{pki_dir}/crl.crt",
                #'ssl-cert-chain'
                #'access-log-config'
                #'graceful-shutdown-timeout' => 60000,
                #'request-header-max-size'
            },
            'nrepl' => {
                'enabled' => 'false',
            },
        }

        # tunes
        settings_tune.each do |k, v|
            next if k == 'cfdb'
            conf[k] = {} if not conf.has_key? k
            conf[k].merge! v
        end
        
        need_restart = false
        
        # whitelist
        if cert_whitelist and !cert_whitelist.empty?
            cert_whitelist_file = "#{conf_root_dir}/cert_whitelist.txt"
            changed = cf_system.atomicWrite(cert_whitelist_file,
                                            cert_whitelist,
                                            { :user => 'puppetdb', :mode => 0600})
            need_restart ||= changed
        end
        
        # write conf
        conf.each do |k, v|
            # That's how puppetdb package creates those...
            if k == 'global'
                f = 'config'
            elsif k == 'nrepl'
                f = 'repl'
            else
                f = k
            end
            
            #next if k == 'read-database'
            
            f = "#{conf_dir}/#{f}.ini"
            changed = cf_system.atomicWriteIni(f, { k => v },
                                               { :user => 'puppetdb', :mode => 0600})
            need_restart ||= changed
        end
        
        # Service File
        #==================================================
        start_timeout = 180
        stop_timeout = 60

        java_args = [
            "-Xms#{(heap_mem/2).to_i}m",
            "-Xmx#{heap_mem}m",
            "-XX:#{meta_param}=#{(meta_mem/2).to_i}m",
            "-XX:Max#{meta_param}=#{meta_mem}m",
        ]

        default_puppetdb_env = '/etc/default/puppetdb'
        puppet_env = [
            "# This file is auto-generated by cfpuppetserver modules",
            %Q{JAVA_BIN="/usr/lib/jvm/java-8-openjdk-amd64/jre/bin/java"},
            %Q{JAVA_ARGS="#{java_args.join(' ')}"},
            %Q{TK_ARGS=""},
            %Q{USER="#{user}"},
            %Q{GROUP="#{user}"},
            %Q{INSTALL_DIR="/opt/puppetlabs/server/apps/puppetdb"},
            %Q{CONFIG="/etc/puppetlabs/puppetdb/conf.d"},
            %Q{BOOTSTRAP_CONFIG="/etc/puppetlabs/puppetdb/bootstrap.cfg"},
            %Q{SERVICE_STOP_RETRIES="#{stop_timeout}"},
            %Q{START_TIMEOUT="#{start_timeout}"},
            %Q{RELOAD_TIMEOUT="#{start_timeout}"},
        ]
        cf_system.atomicWrite(default_puppetdb_env, puppet_env, {:user => user})

        conf_ver = PuppetX::CfSystem.makeVersion([
            conf_root_dir,
            default_puppetdb_env,
        ])

        content_ini = {
            'Unit' => {
                'Description' => "CF PuppetDB",
            },
            'Service' => {
                '# Package Version' => PuppetX::CfSystem::Util.get_package_version('puppetdb'),
                '# Config Digest' => conf_ver,
                'EnvironmentFile' => default_puppetdb_env,
                'Type' => 'forking',
                'ExecStart' => '/opt/puppetlabs/server/apps/puppetdb/bin/puppetdb start',
                'ExecStop' => '/opt/puppetlabs/server/apps/puppetdb/bin/puppetdb stop',
                'ExecReload' => '/opt/puppetlabs/server/apps/puppetdb/bin/puppetdb reload',
                'ExecStartPost' => "#{PuppetX::CfSystem::WAIT_SOCKET_BIN} 8081 #{start_timeout}",
                'KillMode' => 'process',
                'WorkingDirectory' => conf_root_dir,
                'PIDFile' => '/var/run/puppetlabs/puppetdb/puppetdb.pid',
                'TasksMax' => 4915,
                'TimeoutStartSec' => start_timeout,
                'TimeoutStopSec' => stop_timeout,
                'SuccessExitStatus' => 143,
            },
        }
        
        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => user,
            :content_ini => content_ini,
            :cpu_weight => newconf[:cpu_weight],
            :io_weight => newconf[:io_weight],
            :mem_limit => avail_mem,
            :mem_lock => true,
        })
        
        need_restart ||= service_changed
        
        # during migration
        cf_system.maskService("puppetdb")

        #==================================================
        
        if need_restart
            warning(">> reloading #{service_name}")
            systemctl('restart', "#{service_name}.service")
            wait_sock(service_name, conf['jetty']['ssl-port'])
        end        
    end
end
