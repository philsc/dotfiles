# Set up nginx with a default site.
nginx:
  pkg.installed:
    - require:
      - pkg: general_packages

  service.running:
    - require:
      - pkg: nginx
    - watch:
      - file: /etc/nginx/sites-available/default

nginx_default_site:
  file.managed:
    - name: /etc/nginx/sites-available/default
    - source:
      - salt://nginx_default_site
    - template: jinja
    - user: root
    - group: root
    - require:
      - pkg: nginx
