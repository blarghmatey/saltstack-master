master:
  domain: 10.1.0.14

openstack:
  enable: False
  user: salt
  floating_net_uuid: 206ca986-4371-4906-89b3-e143a2abadb8
  fixed_net_uuid: b6454d14-eab8-4b65-b630-8e77d1bbffcd
  identity_domain: 192.168.5.1:5000
  salt_master_domain: 10.1.0.23

aws:
  enable: True