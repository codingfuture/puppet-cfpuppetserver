#!/bin/bash

/opt/puppetlabs/puppet/bin/r10k deploy environment

for penv in /etc/puppetlabs/code/environments/*; do
    pushd $penv
    /opt/puppetlabs/puppet/bin/librarian-puppet install
    popd
done
