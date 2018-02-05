#
# Copyright 2016-2018 (c) Andrey Galkin
#

require 'uri'

Puppet::Functions.create_function(:'cfpuppetserver::uriparse') do
    dispatch :cf_uriparse do
        param 'String[1]', :uri
    end
    
    def cf_uriparse(uri)
        uri = URI.parse uri
        ret = {}
        
        ['scheme', 'host', 'path', 'query', 'fragment'].each { |k|
            ret[k] = uri.send(k)
        }

        return ret
    end
end
