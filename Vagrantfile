# User information
USERNAME = ENV['USER']
NAME = %x< git config user.name >.strip
EMAIL = %x< git config user.email >.strip

# Machine information
HOSTNAME = %x< hostname >.strip + '-dev'

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

class String
  # Strip leading whitespace from each line that is the same as the
  # amount of whitespace on the first line of the string.
  # Leaves _additional_ indentation on later lines intact.
  # SEE: http://stackoverflow.com/a/5638187/504018
  def unindent
    gsub(/^#{self[/\A\s*/]}/, '')
  end
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "trusty-server-cloudimg-amd64-vagrant-disk1"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/#{config.vm.box}.box"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network :public_network
  config.vm.network "forwarded_port", guest: 8000, host: 8000

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  config.vm.provider :virtualbox do |vb|
    # Don't boot with headless mode
    vb.gui = true
    vb.name = HOSTNAME

    # Use VBoxManage to customize the VM.
    vb.customize ["modifyvm", :id, "--memory", "1024"]
    vb.customize ["modifyvm", :id, "--cpus", "2"]
    vb.customize ["modifyvm", :id, "--usb", "on"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # Set up the hostname as requested in the config file.
  config.vm.provision :shell, inline: <<-SH.unindent
    sed -i "s/$(hostname)/#{HOSTNAME}/g" /etc/hosts
    echo #{HOSTNAME} > /etc/hostname
    service hostname restart
  SH

  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-packages"
  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-docker"
  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-user '#{USERNAME}' '#{NAME}' '#{EMAIL}'"

  # Remove unneeded packages.
  config.vm.provision :shell, inline: <<-SH.unindent
    apt-get clean -q -y
  SH

end
