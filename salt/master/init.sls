{% set tls_dir = salt['pillar.get']('master:tls_dir', 'tls') %}
{% set common_name = salt['pillar.get']('master:cert_common_name', 'localhost') %}
{% set random_pass = salt['cmd.run']("uname -a | sha512sum | sed 's/\S*\-$//g'") %}
{% set pillar_pass = salt['pillar.get']('master:ext_pillar:password', random_pass) %}
{% set salt_master_domain = salt['grains.get']('ip_interfaces:eth0', ['salt'])[0] %}
{% set aws_security_group = salt['pillar.get']('aws:security_group', 'default') %}
{% set aws_access_key = salt['cmd.run']('echo $AWS_ACCESS_KEY') %}
{% set aws_secret_key = salt['cmd.run']('echo $AWS_SECRET_KEY') %}
{% set salt_openstack_password = salt['pillar.get']('openstack:password', '') %}
{% set ext_pillar_type = salt['pillar.get']('master:ext_pillar:type', 'redis') %}
{% set ext_pillar_location = salt['pillar.get']('master:ext_pillar:location', 'localhost') %}

master_deps:
  pkg.installed:
    - names:
        - python-pip
        - build-essential
        - libssl-dev
        - python-dev
        - libffi-dev
        - salt-cloud
        - salt-doc

{% if ext_pillar_type == 'redis' %}
master_redis_config:
  file.managed:
    - name: /etc/salt/master.d/redis.conf
    - source: salt://master/master_redis.conf
    - template: jinja
    - require:
        - pkg: salt-master
    - watch_in:
        - service: salt-master
    - context:
        redis_host: {{ salt['pillar.get']('master_redis:host', salt_master_domain) }}
        redis_pass: {{ pillar_pass }}

redis:
  pip.installed:
    - require:
        - pkg: master_deps

{% if ext_pillar_location == 'localhost' %}
redis-server:
  pkg.installed

redis_pass_config:
  file.replace:
    - name: /etc/redis/redis.conf
    - pattern: '^\s*#\s*requirepass.*?$'
    - repl: requirepass {{ pillar_pass }}
    - require:
        - pkg: redis-server

redis_bind_config:
  file.replace:
    - name: /etc/redis/redis.conf
    - pattern: '^.*?bind.*?$'
    - repl: bind 0.0.0.0
    - require:
        - pkg: redis-server

redis-server-service:
  service.running:
    - enable: True
    - require:
        - pkg: master_deps
    - watch:
        - file: redis_pass_config
        - file: redis_bind_config

{% endif %}
{% endif %}

{% if ext_pillar_type == 'mongo' %}
{% set mongo_user = salt['pillar.get']('master_mongo:user', 'salt') %}
{% set mongo_password = salt['pillar.get']('master_mongo:password', pillar_pass) %}
{% set mongo_host = salt['pillar.get']('master_mongo:host', salt_master_domain) %}
{% set mongo_db = salt['pillar.get']('master_mongo:database', 'salt') %}

master_mongo_config:
  file.managed:
    - name: /etc/salt/master.d/mongo.conf
    - source: salt://master/master_mongo.conf
    - template: jinja
    - require:
        - pkg: salt-master
    - watch_in:
        - service: salt-master
    - context:
        mongo_host: {{ mongo_host }}
        mongo_password: {{ mongo_password }}
        mongo_db: {{ mongo_db }}
        mongo_user: {{ mongo_user }}

pymongo:
  pip.installed:
    - require:
        - pkg: master_deps

{% if ext_pillar_location == 'localhost' %}
mongodb-server:
  pkg.installed

mongo_bind_config:
  file.replace:
    - name: /etc/mongodb.conf
    - pattern: '^.*?bind_ip.*?$'
    - repl: bind_ip = 0.0.0.0
    - require:
        - pkg: mongodb-server

mongo_service:
  service.running:
    - enable: True
    - name: mongodb
    - watch:
        - file: mongo_bind_config
    - require:
        - pkg: mongodb-server
{% endif %}
{% endif %}

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


master_pip:
  pip.installed:
    - names:
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

{% if salt['pillar.get']('aws:enable', False) %}
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

aws_sample_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/aws_sample.conf
    - source: salt://master/sample_aws_profile.conf
    - require:
        - file: cloud_profile_dir
{% endif %}

{% if salt['pillar.get']('openstack:enable', False) %}
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
        openstack_identity_domain: {{ salt['pillar.get']('openstack:identity_domain', '') }}
        openstack_project_name: {{ salt['pillar.get']('openstack:project_name', 'admin') }}
        public_network_uuid: {{ salt['pillar.get']('openstack:floating_net_uuid', '') }}
        private_network_uuid: {{ salt['pillar.get']('openstack:fixed_net_uuid', '') }}

openstack_sample_profile:
  file.managed:
    - name: /etc/salt/cloud.profiles.d/openstack_sample.conf
    - source: salt://master/sample_openstack_profile.conf
    - require:
        - file: cloud_profile_dir
{% endif %}

salt-master:
  service.running:
    - enable: True
    - require:
        - pkg: master_deps
    - watch:
        - file: master_halite_config
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
    - unless: cat /etc/salt/keys/salt_master

minion_config_master:
  file.replace:
    - name: /etc/salt/minion
    - pattern: '^.?master:.*?$'
    - repl: 'master: 127.0.0.1'

minion_config_role:
  file.replace:
    - name: /etc/salt/minion
    - pattern: '^.?grains:.*?$'
    - repl: 'grains:\n  roles:\n    - secretary'

salt-minion:
  service.running:
    - enable: True
    - watch:
        - service: salt-master

salt-minion-key:
  cmd.run:
    - name: sleep 10; salt-key -A -y
    - watch:
        - service: salt-minion