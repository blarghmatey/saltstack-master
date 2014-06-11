#!/bin/bash

if [ -z `which salt-minion` ]
then
    wget -O - http://bootstrap.saltstack.org | sudo sh
fi
sudo mkdir -p /srv/salt
sudo mkdir -p /srv/pillar
sudo cp -r salt/* /srv/salt
sudo cp -r pillar/* /srv/pillar
sudo cp minion.conf /etc/salt/minion.d/tripod.conf
sudo salt-call --local state.highstate
