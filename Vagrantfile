# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'


Vagrant.configure("2") do |config|

  # user input on provision
  # https://github.com/hashicorp/vagrant/issues/2662
  class NumInstances
    def to_s
      num_instances = 3

      print "K8s cluster.\n"
      settings = YAML.load_file 'k8s_cluster.yml'
      if not settings then settings = {} end
      if not settings['cluster'] then settings['cluster'] = {} end

      if settings['cluster']['num_instances']
        num_instances = settings['cluster']['num_instances']
        print "num_instances: #{num_instances}\n"
      else
        print "num_instances: "
        STDIN.gets.chomp

        settings['cluster']['num_instances'] = num_instances
        File.write('k8s_cluster.yml', settings.to_yaml)
      end

      num_instances
    end
  end

  class NodeMemory
    def to_s(i)
      node_memory = "2048"

      @settings = YAML.load_file 'k8s_cluster.yml'
      if not @settings then @settings = {} end
      if not @settings['cluster'] then @settings['cluster'] = {} end
      if not @settings['cluster']["node#{i}"] then @settings['cluster']["node#{i}"] = {} end

      if @settings['cluster']["node#{i}"]['memory']
        node_memory = @settings['cluster']["node#{i}"]['memory']
        print "node#{i} memory: #{node_memory}\n"
      else
        print "node#{i} memory: "
        node_memory = STDIN.gets.chomp

        @settings['cluster']["node#{i}"]['memory'] = "#{node_memory}"
        File.write('k8s_cluster.yml', @settings.to_yaml)
      end

      node_memory
    end
  end

  config.vm.box_check_update = false
  config.vm.provider 'virtualbox' do |vb|
   vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 1000 ]
  end  
  config.vm.synced_folder ".", "/vagrant", type: "nfs", nfs_udp: false
  $num_instances = NumInstances.new.to_s.to_i
  # curl https://discovery.etcd.io/new?size=3
  $etcd_cluster = "node1=http://172.17.8.101:2380"
  (1..$num_instances).each do |i|
    config.vm.define "node#{i}" do |node|
      # node.vm.box = "centos/7"
      node.vm.box = "topinfra/centos7-k8s"
      # node.vm.box_version = "1.0.0"
      node.vm.hostname = "node#{i}"
      ip = "172.17.8.#{i+100}"
      node.vm.network "private_network", ip: ip
      node.vm.provider "virtualbox" do |vb|
        vb.memory = NodeMemory.new.to_s(i)
        vb.cpus = 2
        vb.name = "node#{i}"
      end
      node.vm.provision "shell", path: "install.sh", args: [$num_instances, i, ip, $etcd_cluster]
    end
    # VBoxHeadless Consumes all CPU on OSX see: https://github.com/Varying-Vagrant-Vagrants/VVV/issues/694
    # vagrant plugin install vagrant-vbguest
    $enable_serial_logging = false
  end
end
