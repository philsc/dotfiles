{{ pillar['username'] }}:
  user.present:
    - fullname: {{ pillar['fullname'] }}
    - groups:
      - adm
      - cdrom
      - sudo
      - dip
      - plugdev
      - dialout
      - docker
    # Generated via: python -c 'import crypt; print(crypt.crypt("default", "$6$SALTsalt$"));'
    - password: $6$SALTsalt$8Mq/cK7D/pSmxw1mpuZipiiDbLD00Y4e5pNgBjgqI/k2DK2Iwr/c/K.tuoZkJa.HCt3KjGmVXVMNSR4L/3iD.0

dotfiles:
  git.latest:
    name: https://github.com/philsc/dotfiles.git:
    target: /home/{{ pillar['username'] }}/repos/dotfiles
    user: {{ pillar['username'] }}

dotfiles_install:
  cmd.run:
    - name: cd ~/repos/dotfiles && yes | ./install.py
    - user: {{ pillar['username'] }}

/home/{{ pillar['username'] }}/.ssh/id_rsa:
  ssh_auth.present:
    - user: {{ pillar['username'] }}

# Figure out why the value is not set with quotation marks. Right now the git
# name gets set to "Philipp" rather than "Philipp Schrader". Salt invokes it
# like so: git config --global user.name Philipp Schrader
git_name:
  git.config:
    - name: user.name
    - value: {{ pillar['fullname'] }}
    - user: {{ pillar['username'] }}
    - is_global: true

git_email:
  git.config:
    - name: user.email
    - value: {{ pillar['useremail'] }}
    - user: {{ pillar['username'] }}
    - is_global: true
