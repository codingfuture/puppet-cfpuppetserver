#
# Copyright 2016-2017 (c) Andrey Galkin
#

require 'uri'

module Puppet::Parser::Functions
    newfunction(:cfpuppetserver_uriparse, :type => :rvalue) do |args|
        if not args[0]
            raise raise Puppet::ParseError, 'Missing argument to cfpuppetserver_uriparse'
        end

        uri = URI.parse args[0]
        ret = {}
        
        ['scheme', 'host', 'path', 'query', 'fragment'].each { |k|
            ret[k] = uri.send(k)
        }
        
        ret
    end
end
