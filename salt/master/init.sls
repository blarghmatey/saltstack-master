{% set tls_dir = salt['pillar.get']('master:tls_dir', 'tls') %}
{% set common_name = salt['pillar.get']('master:cert_common_name', 'localhost') %}
{% set random_pass = salt['cmd.run']("date | sha512sum | sed 's/\S*\-$//g'") %}
{% set redis_pass = salt['pillar.get']('redis:password', random_pass) %}
{% set salt_master_domain = salt['pillar.get']('master:domain', 'salt') %}
{% set aws_security_group = salt['pillar.get']('aws:security_group', 'default') %}
{% set aws_access_key = salt['cmd.run']('echo $aws_access_key') %}
{% set aws_secret_key = salt['cmd.run']('echo $aws_secret_key') %}
{% set salt_openstack_password = salt['cmd.run']('echo $salt_openstack_password') %}

master_deps:
  pkg.installed:
    - names:
        - redis-server
        - python-pip
        - salt-master

master_redis_config:
  file.managed:
    - name: /etc/salt/master.d/redis.conf
    - source: salt://master/master_redis.conf
    - template: jinja
    - require:
        - pkg: salt-master
    - context:
        redis_pass: {{ redis_pass }}

master_gitfs_config:
  file.managed:
    - name: /etc/salt/master.d/gitfs.conf
    - source: salt://master/master_gitfs.conf
    - require:
        - pkg: salt-master

master_state_config:
  file.append:
    - name: /etc/salt/master
    - text: 'state_output: changes'
    - require:
        - pkg: salt-master

master_halite_config:
  file.managed:
    - name: /etc/salt/master.d/halite.conf
    - source: salt://master/halite.conf
    - template: jinja
    - require:
        - pkg: salt-master
    - context:
        tls_dir: {{ tls_dir }}
        common_name: {{ common_name }}

redis_config:
  file.managed:
    - name: /etc/redis/redis.conf
    - source: salt://master/redis_config.conf
    - template: jinja
    - context:
        redis_pass: {{ redis_pass }}
    - require:
        - pkg: master_deps

master_pip:
  pip.installed:
    - names:
        - redis
        - cherrypy
        - halite
        - PyOpenSSL
        - apache-libcloud
    - require:
        - pkg: python-pip

master_certs:
  module.run:
    - name: tls.create_self_signed_cert
    - require:
        - pip: master_pip

cloud_provider_dir:
  file.directory:
    - name: /etc/salt/cloud.providers.d
    - makedirs: True

cloud_profile_dir:
  file.directory:
    - name: /etc/salt/cloud.profiles.d
    - makedirs: True

aws_base_config:
  file.managed:
    - name: /etc/salt/cloud.providers.d/amazon.conf
    - source: salt://master/aws_config.conf
    - template: jinja
    - require:
        - file: cloud_provider_dir
    - context:
        salt_master_domain: {{ salt_master_domain }}
        aws_access_key: {{ aws_access_key }}
        aws_secret_key: {{ aws_secret_key }}
        aws_security_group: {{ aws_security_group }}
        aws_region: {{ salt['pillar.get']('aws:region', '') }}
        aws_service_url: {{ salt['pillar.get']('aws:service_url', '') }}
        aws_endpoint: {{ salt['pillar.get']('aws:endpoint', '') }}

openstack_base_config:
  file.managed:
    - name: /etc/salt/cloud.providers.d/openstack.conf
    - source: salt://master/openstack_config.conf
    - template: jinja
    - require:
        - file: cloud_provider_dir
    - context:
        salt_master_domain: {{ salt_master_domain }}
        salt_openstack_user: {{ salt['pillar.get']('openstack:user', 'salt') }}
        salt_openstack_password: {{ salt_openstack_password }}
        openstack_region: {{ salt['pillar.get']('openstack:region', 'RegionOne') }}
        openstack_identity_domain: {{ salt['pillar.get']('openstack:identity_domain', '{0}:5000'.format(salt_master_domain)) }}
        openstack_project_name: {{ salt['pillar.get']('openstack:project_name', 'admin') }}

openstack_sample_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/openstack_sample.conf
    - source: salt://master/sample_openstack_profile.conf
    - require:
        - file: cloud_profile_dir

salt-master:
  service.running:
    - enable: True
    - require:
        - pkg: master_deps
    - watch:
        - file: master_halite_config
        - file: master_redis_config
        - file: master_gitfs_config
        - file: cloud_provider_dir

state_dir:
  file.directory:
    - name: /srv/salt
    - makedirs: True

pillar_dir:
  file.directory:
    - name: /srv/pillar
    - makedirs: True

key_dir:
  file.directory:
    - name: /etc/salt/keys
    - require:
        - pkg: master_deps

gen_master_key:
  cmd.run:
    - name: ssh-keygen -f /etc/salt/keys/salt_master -q -N ''
    - require:
        - file: key_dir

redis-server:
  service.running:
    - enable: True
    - require:
        - pkg: master_deps
    - watch:
        - file: redis_config

salt-minion:
  service.dead:
    - require:
        - service: salt-master
