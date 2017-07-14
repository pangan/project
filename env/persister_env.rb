########################################################################################################################
# GENERAL
########################################################################################################################
$PERSISTER_HOSTS = []
$PERSISTER_GROUPS = {}
$PERSISTER_CLUSTER_HOST_VARS = {}

########################################################################################################################
# CONFIGURATION (to be modified)
########################################################################################################################
$PERSISTER_CLUSTER_NODES = 1 #Number of nodes

$PERSISTER_HOSTNAME = "persister"
$PERSISTER_GROUP_NAME = "persister"
$PERSISTER_NETWORK_IPOFFSET = 20

########################################################################################################################
# VIRTUALBOX PROVIDER
########################################################################################################################
$PERSISTER_VBOX_BOXTYPE = "bento/ubuntu-16.04"

########################################################################################################################
# PROVISIONING VARIABLES
########################################################################################################################
persister_hosts = []
(1..$PERSISTER_CLUSTER_NODES).each do |i|
  persister_hosts.push("#{$PERSISTER_HOSTNAME}#{i}")
end

(1..$PERSISTER_CLUSTER_NODES).each do |i|
  ip = {"internal_ip" => "#{$NETWORK_INTERNAL_IP}#{i+$PERSISTER_NETWORK_IPOFFSET}",
        "hostname" => "#{$PERSISTER_HOSTNAME}#{i}",
        "PERSISTER_cluster_id" => "#{i}",
        "PERSISTER_cluster_size" => $PERSISTER_CLUSTER_NODES}
  $PERSISTER_CLUSTER_HOST_VARS["#{$PERSISTER_HOSTNAME}#{i}"] = ip
end

persister_cluster_servers = []
(1..$PERSISTER_CLUSTER_NODES).each do |i|
  persister_cluster_servers.push("#{$NETWORK_INTERNAL_IP}#{i+$PERSISTER_NETWORK_IPOFFSET}")
end

persister_group_vars = {
    "persister_cluster_size" => $PERSISTER_CLUSTER_NODES,
    "ip_offset" => $PERSISTER_NETWORK_IPOFFSET,
    "persister_hosts" => persister_hosts,
    "persister_cluster_servers" => persister_cluster_servers
}

$PERSISTER_GROUPS["#{$PERSISTER_GROUP_NAME}"] = persister_hosts
$PERSISTER_GROUPS["#{$PERSISTER_GROUP_NAME}:vars"] = persister_group_vars

# $CLUSTER_GROUPS = $CLUSTER_GROUPS.merge($GROUPS)
# $CLUSTER_HOST_VARS = $CLUSTER_HOST_VARS.merge($CLUSTER_HOST_VARS)


########################################################################################################################
# DEFINITION
########################################################################################################################
(1..$PERSISTER_CLUSTER_NODES).each do |i|
  Vagrant.configure("2") do |config|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.box_check_update = false

    config.vm.provider "virtualbox" do |v, override|
      override.ssh.username = $VIRTUALBOX_USERNAME
      override.vm.box = $PERSISTER_VBOX_BOXTYPE

      v.customize ["modifyvm", :id, "--cableconnected1", "on"]
    end

    # config.vm.provider "openstack" do |cc, override|
    #   override.ssh.username = $OPENSTACK_CITYCLOUD_ENV_USERNAME
    #
    #   cc.image = $PERSISTER_OPENSTACK_CITYCLOUD_IMAGE
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
    #   cc.floating_ip_pool = $PERSISTER_OPENSTACK_CITYCLOUD_IPPOOL
    # end

    config.vm.define "#{$PERSISTER_HOSTNAME}#{i}" do |g|
      g.vm.hostname = "#{$PERSISTER_HOSTNAME}#{i}"

      g.vm.provider "virtualbox" do |vb, override|
        vb.name = "xproject::#{$PERSISTER_HOSTNAME}#{i}"
        override.vm.network "private_network", ip: "#{$NETWORK_INTERNAL_IP}#{i+$PERSISTER_NETWORK_IPOFFSET}"

        vb.memory = 1024
        vb.cpus = 1
      end

      # g.vm.provider "openstack" do |cc|
      #   cc.server_name = "op5::#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME}::#{$HOSTNAME}#{i}"
      #   cc.project_name = $OPENSTACK_CITYCLOUD_ENV_PROJECTNAME
      #
      #   cc.flavor = $PERSISTER_OPENSTACK_CITYCLOUD_FLAVOUR
      #
      #   $PERSISTER_OPENSTACK_CITYCLOUD_NETWORKS = [{name: $OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_NAME,
      #                                              address: "#{$OPENSTACK_CITYCLOUD_OS_NETWORK_INTERNAL_IP}#{i+$NETWORK_IPOFFSET}"
      #                                             }]
      #
      #   cc.networks = $PERSISTER_OPENSTACK_CITYCLOUD_NETWORKS
      # end

      if i == $PERSISTER_CLUSTER_NODES
        g.vm.provision "ansible" do |ansible|
          ansible.limit="all"
          ansible.playbook = "persister.yml"
          ansible.groups = $PERSISTER_GROUPS
          ansible.host_vars = $PERSISTER_CLUSTER_HOST_VARS
        end
      end
    end
  end
end