########################################################################################################################
# GENERAL
########################################################################################################################
$INFLUXDB_HOSTS = []
$INFLUXDB_GROUPS = {}
$INFLUXDB_CLUSTER_HOST_VARS = {}

########################################################################################################################
# CONFIGURATION (to be modified)
########################################################################################################################
$INFLUXDB_CLUSTER_NODES = 1 #Number of nodes

$INFLUXDB_HOSTNAME = "influxdb"
$INFLUXDB_GROUP_NAME = "influxdb"
$INFLUXDB_NETWORK_IPOFFSET = 20

########################################################################################################################
# VIRTUALBOX PROVIDER
########################################################################################################################
$INFLUXDB_VBOX_BOXTYPE = "bento/ubuntu-16.04"

########################################################################################################################
# PROVISIONING VARIABLES
########################################################################################################################
influxdb_hosts = []
(1..$INFLUXDB_CLUSTER_NODES).each do |i|
  influxdb_hosts.push("#{$INFLUXDB_HOSTNAME}#{i}")
end

(1..$INFLUXDB_CLUSTER_NODES).each do |i|
  ip = {"internal_ip" => "#{$NETWORK_INTERNAL_IP}#{i+$INFLUXDB_NETWORK_IPOFFSET}",
        "hostname" => "#{$INFLUXDB_HOSTNAME}#{i}",
        "influxdb_cluster_id" => "#{i}",
        "influxdb_cluster_size" => $INFLUXDB_CLUSTER_NODES}
  $INFLUXDB_CLUSTER_HOST_VARS["#{$INFLUXDB_HOSTNAME}#{i}"] = ip
end

influxdb_cluster_servers = []
(1..$INFLUXDB_CLUSTER_NODES).each do |i|
  influxdb_cluster_servers.push("#{$NETWORK_INTERNAL_IP}#{i+$INFLUXDB_NETWORK_IPOFFSET}")
end

influxdb_group_vars = {
    "influxdb_cluster_size" => $INFLUXDB_CLUSTER_NODES,
    "ip_offset" => $INFLUXDB_NETWORK_IPOFFSET,
    "influxdb_hosts" => influxdb_hosts,
    "influxdb_cluster_servers" => influxdb_cluster_servers
}

$INFLUXDB_GROUPS["#{$INFLUXDB_GROUP_NAME}"] = influxdb_hosts
$INFLUXDB_GROUPS["#{$INFLUXDB_GROUP_NAME}:vars"] = influxdb_group_vars

$CLUSTER_GROUPS = $CLUSTER_GROUPS.merge($INFLUXDB_GROUPS)
$CLUSTER_HOST_VARS = $CLUSTER_HOST_VARS.merge($INFLUXDB_CLUSTER_HOST_VARS)


########################################################################################################################
# DEFINITION
########################################################################################################################
(1..$INFLUXDB_CLUSTER_NODES).each do |i|
  Vagrant.configure("2") do |config|
    config.vm.synced_folder ".", "/vagrant", disabled: true
    config.vm.box_check_update = false

    config.vm.provider "virtualbox" do |v, override|
      override.ssh.username = $VIRTUALBOX_USERNAME
      override.vm.box = $INFLUXDB_VBOX_BOXTYPE

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

    config.vm.define "#{$INFLUXDB_HOSTNAME}#{i}" do |g|
      g.vm.hostname = "#{$INFLUXDB_HOSTNAME}#{i}"

      g.vm.provider "virtualbox" do |vb, override|
        vb.name = "xproject::#{$INFLUXDB_HOSTNAME}#{i}"
        override.vm.network "private_network", ip: "#{$NETWORK_INTERNAL_IP}#{i+$INFLUXDB_NETWORK_IPOFFSET}"

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

      if i == $INFLUXDB_CLUSTER_NODES
        g.vm.provision "ansible" do |ansible|
          ansible.limit="all"
          ansible.playbook = "influxdb.yml"
          ansible.groups = $CLUSTER_GROUPS
          ansible.host_vars = $CLUSTER_HOST_VARS
        end
      end
    end
  end
end