# User information
USERNAME = ENV['USER']
FULLNAME = %x< git config user.name >.strip
EMAIL = %x< git config user.email >.strip

# Machine information
HOSTNAME = %x< hostname >.strip + '-dev'

# Vagrantfile API/syntax version. Don't touch unless you know what you're 
# doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "trusty-server-cloudimg-amd64-vagrant-disk1"
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/trusty/current/#{config.vm.box}.box"

  config.vm.network :public_network
  config.vm.network :forwarded_port, guest: 8000, host: 8000

  config.vm.synced_folder "salt/roots", "/srv/"

  config.vm.provider :virtualbox do |vb|
    vb.gui = true
    vb.cpus = 2
    vb.memory = 1024
    vb.name = HOSTNAME
    vb.customize ["modifyvm", :id, "--usb", "on"]
  end

  config.vm.provision :salt do |salt|
    salt.minion_config = "salt/minion"
    salt.run_highstate = true
    salt.log_level = "debug"
    salt.verbose = true
    salt.colorize = true

    salt.pillar({
      hostname: HOSTNAME,
      username: USERNAME,
      fullname: FULLNAME,
      useremail: EMAIL,
    })
  end
end
