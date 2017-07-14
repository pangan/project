########################################################################################################################
# GENERAL
########################################################################################################################
$KAFKA_HOSTS = []
$KAFKA_GROUPS = {}
$KAFKA_CLUSTER_HOST_VARS = {}

########################################################################################################################
# CONFIGURATION (to be modified)
########################################################################################################################
$KAFKA_CLUSTER_NODES = 1 #Number of nodes

$KAFKA_HOSTNAME = "kafka"
$KAFKA_GROUP_NAME = "kafka"
$KAFKA_NETWORK_IPOFFSET = 20

########################################################################################################################
# VIRTUALBOX PROVIDER
########################################################################################################################
$KAFKA_VBOX_BOXTYPE = "bento/ubuntu-16.04"

########################################################################################################################
# PROVISIONING VARIABLES
########################################################################################################################
kafka_hosts = []
(1..$KAFKA_CLUSTER_NODES).each do |i|
  kafka_hosts.push("#{$KAFKA_HOSTNAME}#{i}")
end

(1..$KAFKA_CLUSTER_NODES).each do |i|
  ip = {"internal_ip" => "#{$NETWORK_INTERNAL_IP}#{i+$KAFKA_NETWORK_IPOFFSET}",
        "hostname" => "#{$KAFKA_HOSTNAME}#{i}",
        "kafka_cluster_id" => "#{i}",
        "kafka_cluster_size" => $KAFKA_CLUSTER_NODES}
  $KAFKA_CLUSTER_HOST_VARS["#{$KAFKA_HOSTNAME}#{i}"] = ip
end

kafka_cluster_servers = []
(1..$KAFKA_CLUSTER_NODES).each do |i|
  kafka_cluster_servers.push("#{$NETWORK_INTERNAL_IP}#{i+$KAFKA_NETWORK_IPOFFSET}")
end

kafka_group_vars = {
    "kafka_cluster_size" => $KAFKA_CLUSTER_NODES,
    "ip_offset" => $KAFKA_NETWORK_IPOFFSET,
    "kafka_hosts" => kafka_hosts,
    "kafka_cluster_servers" => kafka_cluster_servers
}

$KAFKA_GROUPS["#{$KAFKA_GROUP_NAME}"] = kafka_hosts
$KAFKA_GROUPS["#{$KAFKA_GROUP_NAME}:vars"] = kafka_group_vars

# $CLUSTER_GROUPS = $CLUSTER_GROUPS.merge($GROUPS)
# $CLUSTER_HOST_VARS = $CLUSTER_HOST_VARS.merge($CLUSTER_HOST_VARS)


########################################################################################################################
# DEFINITION
########################################################################################################################
(1..$KAFKA_CLUSTER_NODES).each do |i|
  Vagrant.configure("2") do |config|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.box_check_update = false

    config.vm.provider "virtualbox" do |v, override|
      override.ssh.username = $VIRTUALBOX_USERNAME
      override.vm.box = $KAFKA_VBOX_BOXTYPE

      v.customize ["modifyvm", :id, "--cableconnected1", "on"]
    end

    # config.vm.provider "openstack" do |cc, override|
    #   override.ssh.username = $OPENSTACK_CITYCLOUD_ENV_USERNAME
    #
    #   cc.image = $KAFKA_OPENSTACK_CITYCLOUD_IMAGE
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
    #   cc.floating_ip_pool = $KAFKA_OPENSTACK_CITYCLOUD_IPPOOL
    # end

    config.vm.define "#{$KAFKA_HOSTNAME}#{i}" do |g|
      g.vm.hostname = "#{$KAFKA_HOSTNAME}#{i}"

      g.vm.provider "virtualbox" do |vb, override|
        vb.name = "xproject::#{$KAFKA_HOSTNAME}#{i}"
        override.vm.network "private_network", ip: "#{$NETWORK_INTERNAL_IP}#{i+$KAFKA_NETWORK_IPOFFSET}"

        vb.memory = 1024
        vb.cpus = 1
      end

      # g.vm.provider "openstack" do |cc|
      #   cc.server_name = "op5::#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME}::#{$HOSTNAME}#{i}"
      #   cc.project_name = $OPENSTACK_CITYCLOUD_ENV_PROJECTNAME
      #
      #   cc.flavor = $KAFKA_OPENSTACK_CITYCLOUD_FLAVOUR
      #
      #   $KAFKA_OPENSTACK_CITYCLOUD_NETWORKS = [{name: $OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME,
      #                                              address: "#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}"
      #                                             }]
      #
      #   cc.networks = $KAFKA_OPENSTACK_CITYCLOUD_NETWORKS
      # end

      if i == $KAFKA_CLUSTER_NODES
        g.vm.provision "ansible" do |ansible|
          ansible.limit="all"
          ansible.playbook = "kafka.yml"
          ansible.groups = $KAFKA_GROUPS
          ansible.host_vars = $KAFKA_CLUSTER_HOST_VARS
        end
      end
    end
  end
end