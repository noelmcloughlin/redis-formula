{% from "redis/map.jinja" import redis_settings with context %}


{% set install_from   = redis_settings.install_from -%}


{% if install_from in ('source', 'archive') %}
{% set version = redis_settings.version|default('2.8.8') -%}
{% set checksum = redis_settings.checksum|default('sha1=aa811f399db58c92c8ec5e48271d307e9ab8eb81') -%}
{% set root = redis_settings.root|default('/usr/local') -%}

{# there is a missing config template for version 2.8.8 #}

redis-dependencies:
  pkg.installed:
    - names:
        - {{ redis_settings.python_dev_package }}
    {% if grains['os_family'] == 'RedHat' %}
        - make
        - libxml2-devel
    {% elif grains['os_family'] == 'Debian' or grains['os_family'] == 'Ubuntu' %}
        - build-essential
        - libxml2-dev
    {% endif %}

get-redis:
  file.managed:
    - name: {{ root }}/redis-{{ version }}.tar.gz
    - source: http://download.redis.io/releases/redis-{{ version }}.tar.gz
    - source_hash: {{ checksum }}
    - makedirs: True
    - require:
      - pkg: redis-dependencies
  cmd.wait:
    - cwd: {{ root }}
    - names:
      - tar -zxvf {{ root }}/redis-{{ version }}.tar.gz -C {{ root }} >/dev/null
    - watch:
      - file: get-redis


make-and-install-redis:
  cmd.wait:
    - cwd: {{ root }}/redis-{{ version }}
    - names:
      - make >/dev/null 2>&1
      - make install >/dev/null 2>&1
    - watch:
      - cmd: get-redis

install-redis-service:
  cmd.wait:
    - cwd: {{ root }}/redis-{{ version }}
    - names:
      - echo -n | utils/install_server.sh
    - watch:
      - cmd: get-redis
      - cmd: make-and-install-redis
    - require:
      - cmd: make-and-install-redis


{% elif install_from == 'package' %}


install-redis:
  pkg.installed:
    - name: {{ redis_settings.pkg_name }}
    {% if redis_settings.version is defined %}
    - version: {{ redis_settings.version }}
    - ignore_epoch: True
    {% endif %}

    {%- if grains.os_family|lower == 'suse' %}
        {# this is basically a workaround for faulty packaging #}
install-redis-log:
  group.present:
    - name: {{ redis_settings.group }}
  user.present:
    - name: {{ redis_settings.user }}
    - gid_from_name: True
    - home: {{ redis_settings.home }}
    - require:
      - group: install-redis-log
  file.directory:
    - name: /var/log/redis
    - mode: 755
    - user: {{ redis_settings.user }}
    - group: {{ redis_settings.group }}
    - recurse:
        - user
        - group
        - mode
    - makedirs: True
    - require:
      - user: install-redis-log

install-redis-service:
  file.replace:
    - name: /usr/lib/systemd/system/redis@.service
    - pattern: ^Type=notify
    - repl: Type=simple
  cmd.run:
    - name: systemctl daemon-reload
    - require:
      - file: install-redis-log
    {% endif %}

{% endif %}
