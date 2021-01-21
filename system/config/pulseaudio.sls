# Disable pulseaudio in client mode so that we use the system instance.
pulse_settings_client:
  file.managed:
    - name: /etc/pulse/client.conf
    - mode: 644
    - contents: |
        # This file is managed by SaltStack.
        # I recommend _against_ editing this file by hand.
        default-server = /var/run/pulse/native
        autospawn = no

# Add a systemd service file to start pulseaudio in system mode.
pulse_system_daemon_service:
  file.managed:
    - name: /lib/systemd/system/pulse-audio-system.service
    - mode: 644
    - contents: |
        [Unit]
        Description=PulseAudio system server

        [Service]
        Type=simple
        ExecStart=/usr/bin/pulseaudio --daemonize=no --system --realtime --log-target=journal

        [Install]
        WantedBy=multi-user.target

pulse_system_daemon:
  service.enabled:
    - name: pulse-audio-system
    - require:
      - file: pulse_system_daemon_service

service.systemctl_reload:
  module.run:
    - onchanges:
      - file: pulse_system_daemon_service

{% for unit in ("pulseaudio.service", "pulseaudio.socket") %}
user_{{ unit.replace(".", "_") }}:
  service.masked:
    - name: {{ unit }}
{% endfor %}

# TODO(phil): Figure out what this does. I vaguely remember that this is used
# to decouple output volume streams from one another.
tweak_pulseaudio_daemon_conf:
  file.append:
    - name: /etc/pulse/daemon.conf
    - text: |
        flat-volumes = no
