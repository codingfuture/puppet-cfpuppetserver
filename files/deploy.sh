#!/bin/bash

export PATH="/opt/puppetlabs/bin/:/opt/puppetlabs/puppet/bin/:$PATH"
/opt/puppetlabs/puppet/bin/r10k deploy environment

for penv in /etc/puppetlabs/code/environments/*; do
    pushd $penv >/dev/null
    /opt/puppetlabs/puppet/bin/librarian-puppet install
    popd >/dev/null
done

chown -R puppet:puppet /etc/puppetlabs/code/environments/
