# The microphone has a lot of static. Enable the noechosource.
noechosink_enable:
  file.append:
    - name: /etc/pulse/system.pa
    - text: |
        load-module module-echo-cancel source_name=noechosource sink_name=noechosink
        set-default-source noechosource
        set-default-sink noechosink
