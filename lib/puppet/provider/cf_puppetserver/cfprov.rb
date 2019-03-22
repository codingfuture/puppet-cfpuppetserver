#
# Copyright 2016-2019 (c) Andrey Galkin
#


require File.expand_path( '../../../../puppet_x/cf_puppet_server', __FILE__ )


Puppet::Type.type(:cf_puppetserver).provide(
    :cfprov,
    :parent => PuppetX::CfPuppetServer::ProviderBase
) do
    desc "Provider for cfdb_access"
    
    commands :sudo => PuppetX::CfSystem::SUDO
    commands :systemctl => PuppetX::CfSystem::SYSTEMD_CTL
        
    def self.get_config_index
        'cf20puppet1server'
    end

    def self.get_generator_version
        cf_system().makeVersion(__FILE__)
    end
    
    def self.check_exists(params)
        debug("check_exists: #{params}")
        begin
            systemctl(['status', "#{params[:service_name]}.service"])
        rescue => e
            warning(e)
            #warning(e.backtrace)
            false
        end
    end    

    def self.on_config_change(newconf)
        debug('on_config_change')
        
        newconf = newconf[newconf.keys[0]]
        service_name = newconf[:service_name]
        
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
        
        conf_root_dir = '/etc/puppetlabs/puppetserver'
        conf_dir = "#{conf_root_dir}/conf.d"
        
        need_restart = false
        
        # Service File
        #==================================================
        bootstrap_path = [
            "#{conf_root_dir}/services.d/",
            '/opt/puppetlabs/server/apps/puppetserver/config/services.d/'
        ].join(',')
        
        start_timeout = 180

        jars = [
            "/opt/puppetlabs/server/apps/puppetserver/puppet-server-release.jar",
            #"/opt/puppetlabs/server/apps/puppetserver/jruby-1_7.jar",
            '/opt/puppetlabs/server/apps/puppetserver/jruby-9k.jar',
            "/opt/puppetlabs/server/data/puppetserver/jars/*",
        ].join(':')

        conf_ver = PuppetX::CfSystem.makeVersion([
            conf_root_dir,
            '/etc/puppetlabs/puppet/puppet.conf',
            '/etc/puppetlabs/puppet/puppetdb.conf'
        ])

        content_ini = {
            'Unit' => {
                'Description' => "CF PuppetServer",
            },
            'Service' => {
                '# Package Version' => PuppetX::CfSystem::Util.get_package_version('puppetserver'),
                '# Config Digest' => conf_ver,
                'ExecStart' => [
                    '/usr/bin/java',
                    '-XX:OnOutOfMemoryError=kill\s-9\s%%p',
                    '-Djava.security.egd=/dev/urandom',
                    "-Xms#{(heap_mem/2).to_i}m",
                    "-Xmx#{heap_mem}m",
                    "-XX:#{meta_param}=#{(meta_mem/2).to_i}m",
                    "-XX:Max#{meta_param}=#{meta_mem}m",
                    "-cp #{jars}",
                    'clojure.main -m puppetlabs.trapperkeeper.main',
                    '--config ', conf_dir,
                    "-b '#{bootstrap_path}'",
		    '--restart-file /opt/puppetlabs/server/data/puppetserver/restartcounter',
                ].join(' '),
                'ExecReload' => '/bin/kill -HUP $MAINPID',
                'ExecStartPost' => "#{PuppetX::CfSystem::WAIT_SOCKET_BIN} 8140 #{start_timeout}",
                'WorkingDirectory' => conf_root_dir,
                'TimeoutStartSec' => "#{start_timeout}",
                'TimeoutStopSec' => "60",
            },
        }
        
        service_changed = self.cf_system().createService({
            :service_name => service_name,
            :user => 'puppet',
            :content_ini => content_ini,
            :cpu_weight => newconf[:cpu_weight],
            :io_weight => newconf[:io_weight],
            :mem_limit => avail_mem,
            :mem_lock => true,
        })
        
        need_restart ||= service_changed
        
        # during migration
        cf_system.maskService('puppetserver')

        #==================================================
        
        if need_restart
            warning(">> reloading #{service_name}")
            systemctl('restart', "#{service_name}.service")
            wait_sock(service_name, 8140)
        end        
    end
end
