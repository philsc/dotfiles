# The microphone has a lot of static. Enable the noechosource.
noechosink_enable:
  file.append:
    - name: /etc/pulse/system.pa
    - text: |
        load-module module-echo-cancel source_name=noechosource sink_name=noechosink
        set-default-source noechosource
        set-default-sink noechosink

# Make it easier to play Star Citizen.
max_map_count_sysctl_file:
  file.managed:
    - name: /etc/sysctl.d/0-star_citizen.conf
    - mode: 644
    - contents: |
        # Increase resource limit to improve Star Citizen performance.
        vm.max_map_count = 16777216
