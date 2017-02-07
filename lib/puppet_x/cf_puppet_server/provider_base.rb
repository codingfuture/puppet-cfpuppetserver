#
# Copyright 2016-2017 (c) Andrey Galkin
#


module PuppetX::CfPuppetServer
    class ProviderBase < PuppetX::CfSystem::ProviderBase
        def self.wait_sock(service_name, service_port)
            PuppetX::CfSystem::Util.wait_sock(service_name, service_port, 180, 20)
        end
        
        def self.is_jvm_metaspace
            PuppetX::CfSystem::Util.is_jvm_metaspace
        end
    end
end
