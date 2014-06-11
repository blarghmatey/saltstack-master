include:
  - nginx
  - uwsgi

halite_uwsgi_config:
  file.managed:
    - name: /etc/uwsgi/vassals/halite.ini
    - source: salt://halite/uwsgi.ini
    - require:
        - sls: uwsgi

halite_nginx_config:
  file.managed:
    - name: /etc/nginx/sites-available/halite
    - source: salt://halite/nginx.conf
      - require:
          - sls: nginx