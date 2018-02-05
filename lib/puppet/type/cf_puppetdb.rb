#
# Copyright 2016-2018 (c) Andrey Galkin
#

require 'puppet/property/boolean'

Puppet::Type.newtype(:cf_puppetdb) do
    desc "DO NOT USE DIRECTLY."
    
    autorequire(:cfsystem_flush_config) do
        ['begin']
    end
    autorequire(:cfsystem_memory_calc) do
        ['total']
    end
    autonotify(:cfsystem_flush_config) do
        ['commit']
    end
    
    ensurable do
        defaultvalues
        defaultto :absent
    end
    
    newparam(:name) do
        isnamevar
    end
    
    newproperty(:cpu_weight) do
        isrequired
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end
    
    newproperty(:io_weight) do
        isrequired
        validate do |value|
            unless value.is_a? Integer and value > 0
                raise ArgumentError, "%s is not a valid positive integer" % value
            end
        end
    end

    [:dbaccess, :rodbaccess].each do |v|
        newproperty(v) do
            isrequired
            validate do |value|
                value.is_a? Hash and \
                    value['db'].length and \
                    value['maxconn'].to_i > 0 and \
                    value['host'].length and \
                    value['port'].to_i > 0 and \
                    value['user'].length and \
                    value['pass'].length
            end
        end
    end
    
    newproperty(:port) do
        isrequired
        validate do |value|
            value.is_a? Integer
        end
    end
    
    newproperty(:service_name) do
        isrequired
        validate do |value|
            unless value =~ /^[a-z0-9_@-]+$/i
                raise ArgumentError, "%s is not a valid service name" % value
            end
        end
    end

    newproperty(:cert_whitelist, :array_matching => :all) do
        validate do |value|
            value.is_a? String
        end
    end
    
    newproperty(:settings_tune) do
        validate do |value|
            value.is_a? Hash
        end
    end
end
