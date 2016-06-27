
# Done this way due to some weird behavior in tests also ignoring $LOAD_PATH
begin
    require File.expand_path( '../cf_system', __FILE__ )
rescue LoadError
    require File.expand_path( '../../../../cfsystem/lib/puppet_x/cf_system', __FILE__ )
end

module PuppetX::CfPuppetServer
    BASE_DIR = File.expand_path('../', __FILE__)
    
    #---
    require "#{BASE_DIR}/cf_puppet_server/provider_base"
end
