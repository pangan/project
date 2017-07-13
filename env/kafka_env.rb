########################################################################################################################
# GENERAL
########################################################################################################################
$HOSTS = []
$GROUPS = {}
$CLUSTER_HOST_VARS = {}

########################################################################################################################
# CONFIGURATION (to be modified)
########################################################################################################################
$CLUSTER_NODES = 1 #Number of nodes

$HOSTNAME = "kafka"
$GROUP_NAME = "kafka"
$NETWORK_IPOFFSET = 10

########################################################################################################################
# VIRTUALBOX PROVIDER
########################################################################################################################
$VBOX_BOXTYPE = "bento/ubuntu-16.04"

########################################################################################################################
# PROVISIONING VARIABLES
########################################################################################################################
hosts = []
(1..$CLUSTER_NODES).each do |i|
  hosts.push("#{$HOSTNAME}#{i}")
end

(1..$CLUSTER_NODES).each do |i|
  ip = {"internal_ip" => "#{$NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}",
        "hostname" => "#{$HOSTNAME}#{i}",
        "cluster_id" => "#{i}",
        "cluster_size" => $CLUSTER_NODES}
  $CLUSTER_HOST_VARS["#{$HOSTNAME}#{i}"] = ip
end

cluster_servers = []
(1..$CLUSTER_NODES).each do |i|
  cluster_servers.push("#{$NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}")
end

group_vars = {
    "cluster_size" => $CLUSTER_NODES,
    "ip_offset" => $NETWORK_IPOFFSET,
    "hosts" => hosts,
    "cluster_servers" => cluster_servers
}

$GROUPS["#{$GROUP_NAME}"] = hosts
$GROUPS["#{$GROUP_NAME}:vars"] = group_vars

# $CLUSTER_GROUPS = $CLUSTER_GROUPS.merge($GROUPS)
# $CLUSTER_HOST_VARS = $CLUSTER_HOST_VARS.merge($CLUSTER_HOST_VARS)


########################################################################################################################
# DEFINITION
########################################################################################################################
(1..$CLUSTER_NODES).each do |i|
  Vagrant.configure("2") do |config|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.box_check_update = false

    config.vm.provider "virtualbox" do |v, override|
      override.ssh.username = $VIRTUALBOX_USERNAME
      override.vm.box = $VBOX_BOXTYPE

      v.customize ["modifyvm", :id, "--cableconnected1", "on"]
    end

    # config.vm.provider "openstack" do |cc, override|
    #   override.ssh.username = $OPENSTACK_CITYCLOUD_ENV_USERNAME
    #
    #   cc.image = $INFLUXDB_OPENSTACK_CITYCLOUD_IMAGE
    #
    #   cc.identity_api_version = $OPENSTACK_CITYCLOUD_OS_IDENTITY_API_VERSION
    #
    #   cc.security_groups = $OPENSTACK_CITYCLOUD_OS_SECURITY_GROUPS
    #
    #   cc.domain_name = $OPENSTACK_CITYCLOUD_OS_DOMAIN_NAME
    #   cc.project_name = $OPENSTACK_CITYCLOUD_OS_PROJECT_NAME
    #
    #   cc.openstack_auth_url = $OPENSTACK_CITYCLOUD_OS_AUTH_URL
    #
    #   cc.username = $OPENSTACK_CITYCLOUD_OS_USERNAME
    #   cc.password = $OPENSTACK_CITYCLOUD_OS_PASSWORD
    #
    #   cc.region = $OPENSTACK_CITYCLOUD_ENV_REGION
    #
    #
    #   cc.openstack_network_url = $OPENSTACK_CITYCLOUD_ENV_NETWORK_URL
    #   cc.openstack_image_url = $OPENSTACK_CITYCLOUD_ENV_IMAGE_URL
    #
    #   cc.floating_ip_pool = $INFLUXDB_OPENSTACK_CITYCLOUD_IPPOOL
    # end

    config.vm.define "#{$HOSTNAME}#{i}" do |g|
      g.vm.hostname = "#{$HOSTNAME}#{i}"

      g.vm.provider "virtualbox" do |vb, override|
        vb.name = "xproject::#{$HOSTNAME}#{i}"
        override.vm.network "private_network", ip: "#{$NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}"

        vb.memory = 1024
        vb.cpus = 1
      end

      # g.vm.provider "openstack" do |cc|
      #   cc.server_name = "op5::#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME}::#{$HOSTNAME}#{i}"
      #   cc.project_name = $OPENSTACK_CITYCLOUD_ENV_PROJECTNAME
      #
      #   cc.flavor = $INFLUXDB_OPENSTACK_CITYCLOUD_FLAVOUR
      #
      #   $INFLUXDB_OPENSTACK_CITYCLOUD_NETWORKS = [{name: $OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME,
      #                                              address: "#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}"
      #                                             }]
      #
      #   cc.networks = $INFLUXDB_OPENSTACK_CITYCLOUD_NETWORKS
      # end

      if i == $CLUSTER_NODES
        g.vm.provision "ansible" do |ansible|
          ansible.limit="all"
          ansible.playbook = "kafka.yml"
          ansible.groups = $GROUPS
          ansible.host_vars = $CLUSTER_HOST_VARS
        end
      end
    end
  end
end