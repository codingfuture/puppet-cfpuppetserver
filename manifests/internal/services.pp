
# Please see README
class cfpuppetserver::internal::services {
#     if is_bool($cfpuppetserver::puppetdb) and $cfpuppetserver::puppetdb {
#         service{ $cfpuppetserver::puppetdb::service_name:
#             ensure => running,
#             enable => true,
#         }
#     }
#     
#     if $cfpuppetserver::puppetserver {
#         service{ $cfpuppetserver::puppetserver::service_name:
#             ensure => running,
#             enable => true,
#         }
#     }
}
