USERNAME = ENV['USER']
NAME = %x< git config --global user.name >.strip
EMAIL = %x< git config --global user.email >.strip

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
  config.vm.box = "trusy-server-cloudimg-amd64-vagrant-disk1"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  config.vm.network :public_network

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider :virtualbox do |vb|
    # Don't boot with headless mode
    vb.gui = true
    vb.name = HOSTNAME

    # Use VBoxManage to customize the VM.
    vb.customize ["modifyvm", :id, "--memory", "1024"]
    vb.customize ["modifyvm", :id, "--cpus", "2"]
    vb.customize ["modifyvm", :id, "--usb", "on"]
  end

  # Set up the hostname as requested in the config file.
  config.vm.provision :shell, inline: <<-SH.unindent
    sed -i "s/$(hostname)/#{HOSTNAME}/g" /etc/hosts
    echo #{HOSTNAME} > /etc/hostname
    service hostname restart
    SH

  # Install essentials like git and the 32-bit compatiblity libraries.
  config.vm.provision :shell, inline: <<-SH.unindent
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -q
    apt-get upgrade -q -y
    apt-get install -q -y subversion git
    apt-get install -q -y lib32z1 lib32ncurses5 lib32bz2-1.0
    SH

  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-docker"
  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-packages"
  config.vm.provision :shell, inline: "/vagrant/vagrant/setup-user '#{USERNAME}' '#{NAME}' '#{EMAIL}'"

  # Remove unneeded packages.
  config.vm.provision :shell, inline: <<-SH.unindent
    apt-get clean -q -y
    SH

end
