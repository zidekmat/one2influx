# Wrapper for function that loads all data from OpenNebula
class One2Influx::Data

  attr_reader :points

  # Loads all data from ONE according to $CFG and stores it in
  #  instance variable @points
  def initialize
    @points = []
    counter = {hosts: 0, vms: 0, dss: 0, clusters: 0}
    # Connect to ONE
    @client = OpenNebula::Client.new($CFG.one[:credentials], $CFG.one[:endpoint])

    # Load pool of all hosts
    host_pool = OpenNebula::HostPool.new(@client)
    rc = host_pool.info
    raise rc.message if OpenNebula.is_error?(rc)

    # Get data from all hosts in the pool
    hosts_xml = {} # XML of all hosts, passed to theirs cluster
    oo_hosts = []  # array of all instances of OneObject::Host
    host_pool.each do |one_host|
      host = ::One2Influx::Host.new(one_host.to_xml, @client)
      # Get data from all VMs belonging to current host
      host.vms.each do |vm_id|
        xml_rep = OpenNebula::VirtualMachine.build_xml(vm_id)
        one_vm = OpenNebula::VirtualMachine.new(xml_rep, @client)
        rc = one_vm.info
        raise rc.message if OpenNebula.is_error?(rc)
        vm = ::One2Influx::VirtualMachine.new(one_vm.to_xml, @client, host)
        @points += vm.serialize_as_points
        counter[:vms] += 1
      end
      hosts_xml[host.tags[:HOST_ID]] = one_host.to_xml
      oo_hosts << host
      @points += host.serialize_as_points
      counter[:hosts] += 1
    end

    # Load pool of all clusters
    cluster_pool = OpenNebula::ClusterPool.new(@client)
    rc = cluster_pool.info
    raise rc.message if OpenNebula.is_error?(rc)

    # Get data from all clusters in the pool
    cluster_pool.each do |one_cluster|
      cluster = ::One2Influx::Cluster.new(one_cluster.to_xml, @client,hosts_xml)
      @points += cluster.serialize_as_points
      counter[:clusters] += 1
    end

    # Load pool of all datastores
    ds_pool = OpenNebula::DatastorePool.new(@client)
    rc = ds_pool.info
    raise rc.message if OpenNebula.is_error?(rc)

    # Get hash of all hosts for every datastore if these tags are required
    # It has form {DS_ID_1: [HOST_ID_1, HOST_ID_2, ...], ...}
    ds_has_hosts = {}
    if $CFG.storage[:ds][:tags].has_key? :HOSTS_IDS
      oo_hosts.each do |host|
        host.datastores.each do |ds|
          ds_has_hosts[ds] ||= []
          ds_has_hosts[ds] << host.tags[:HOST_ID]
        end
      end
    end

    # Get data from all datastores in the pool
    ds_pool.each do |one_ds|
      ds = ::One2Influx::Datastore.new(one_ds.to_xml, @client)
      hosts = ds_has_hosts[ds.tags[:DS_ID]]
      hosts ||= []
      # This doesn't do anything if tag HOSTS_IDS is not enabled
      ds.add_hosts_ids(hosts)
      @points += ds.serialize_as_points
      counter[:dss] += 1
    end

    $LOG.info "Fetched data for #{counter[:vms]} VMs, #{counter[:hosts]} hosts" +
                  ", #{counter[:dss]} datastores and #{counter[:clusters]} " +
                  'clusters.'
  end
end