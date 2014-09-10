#!/bin/bash

if [ -z `which salt-minion` ]
then
    curl -o install_salt.sh -L https://bootstrap.saltstack.com
    sudo sh install_salt.sh -M git v2014.1.10
fi
sudo mkdir -p /srv/salt
sudo mkdir -p /srv/pillar
sudo mkdir -p /srv/formulas
sudo cp -r salt/* /srv/salt
sudo cp -r pillar/* /srv/pillar
sudo cp minion.conf /etc/salt/minion.d/minion.conf
sudo salt-call --local state.highstate
