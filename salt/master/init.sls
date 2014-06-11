{% set tls_dir = salt['pillar.get']('master:tls_dir', 'tls') %}
{% set common_name = salt['pillar.get']('master:cert_common_name', 'localhost') %}

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
    - makedirs: True

master_gitfs_config:
  file.managed:
    - name: /etc/salt/mater.d/gitfs.conf
    - source: salt://master/master_gitfs.conf
    - makedirs: True

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
    - require:
        - pkg: salt-master
    - context:
        - tls_dir: {{ tls_dir }}
        - common_name: {{ common_name }}

master_pip:
  pip.installed:
    - names:
        - redis
        - cherrypy
        - halite
        - PyOpenSSL
    - require:
        - pkg: python-pip

master_certs:
  module.run:
    - name: tls.create_self_signed_cert
    - require:
        - pip: master_pip

salt-master:
  service.running:
    - enabled: True
    - require:
        - pkg: master_deps

redis:
  service.running:
    - enabled: True
    - require:
        - pkg: master_deps