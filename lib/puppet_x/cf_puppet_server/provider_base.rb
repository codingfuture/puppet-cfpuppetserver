#
# Copyright 2016-2017 (c) Andrey Galkin
#


module PuppetX::CfPuppetServer
    class ProviderBase < PuppetX::CfSystem::ProviderBase
        def self.wait_sock(service_name, service_port)
            sleep 20
            for i in 1..180
                return true if res = netstat('-tln').include?(":#{service_port}")
                
                
                warning("Waiting #{service_name} startup (#{i})!")
                sleep 1
            end
            
            fail("Failed to wait for #{service_name} startup")
        end
        
        def self.is_jvm_metaspace
            res = Puppet::Util::Execution.execute(
                ['/usr/bin/java', '-XX:MaxMetaspaceSize=8m', '-version'],
                {
                    :failonfail => false,
                    :squelch => true,
                    :uid => 'puppet',
                    :gid => 'puppet',
                }
            )
            
            res.exitstatus == 0
        end
    end
end
