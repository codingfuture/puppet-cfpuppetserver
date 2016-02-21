# Change Log

All notable changes to this project will be documented in this file. This
project adheres to [Semantic Versioning](http://semver.org/).

## [0.9.0]

- Changed to use puppetlabs/postgresql and puppetlabs/puppetdb for installation
- Implemented full forceful setup of configuration
- Implemented `librarian-puppet` based dependency installation instead of not
   incomplete implementation in r10k. See [RK-3](https://tickets.puppetlabs.com/browse/RK-3).
    - No more need to include dependencies of dependencies in Puppetfile
    - Puppetfile.lock is now supported
- Bugfixes for parameter handling
- Bugfix: opened HTTPS port for Puppet Forge
- Added automatic memory limit configuration for installed services
- Changed $puppet_git_host to $repo_url
- Added new configuration variables

## [0.1.2]

- Added hiera.yaml version 4 support
- Added Puppt Server infrastructure initialization script

## [0.1.1]

- No changes (missed merge)

## [0.1.0]

Initial release

[0.9.0]: https://github.com/codingfuture/puppet-cfpuppetserver/releases/tag/v0.9.0
[0.1.2]: https://github.com/codingfuture/puppet-cfpuppetserver/releases/tag/v0.1.2
[0.1.1]: https://github.com/codingfuture/puppet-cfpuppetserver/releases/tag/v0.1.1
[0.1.0]: https://github.com/codingfuture/puppet-cfpuppetserver/releases/tag/v0.1.0

