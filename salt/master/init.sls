{% set tls_dir = salt['pillar.get']('master:tls_dir', 'tls') %}
{% set common_name = salt['pillar.get']('master:cert_common_name', 'localhost') %}
{% set redis_pass = salt['pillar.get']('redis:passord', 'S0m3R3@1ly!0ngP@55w0rd' %}

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
        redis_pass: {{ redis_pass) }}
    - require:
        - pkg: master_deps

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
    - enable: True
    - require:
        - pkg: master_deps
    - watch:
        - file: /etc/master.d/*

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