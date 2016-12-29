#
# Copyright 2016 (c) Andrey Galkin
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
    end
end
