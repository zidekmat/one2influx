require 'nokogiri'
class One2Influx::FakeData

  attr_reader :points

  def initialize
    @points = []
    counter = {hosts: 0, vms: 0, dss: 0, clusters: 0}
    fake_one = One2Influx::FakeOne.new

    # Get data from all hMEM_USAGEosts in the pool
    hosts_xml = {}
    oo_hosts = []
    fake_one.hosts.each do |one_host|
      host = ::One2Influx::Host.new(one_host[:xml], nil)
      # Get data from all VMs belonging to current host
      fake_one.get_vms(one_host[:hash][:HOST][:ID]).each do |one_vm|
        vm = ::One2Influx::VirtualMachine.new(one_vm, nil, host)
        @points += vm.serialize_as_points
        counter[:vms] += 1
      end
      hosts_xml[host.tags[:HOST_ID]] = one_host[:xml]
      oo_hosts << host
      @points += host.serialize_as_points
      counter[:hosts] += 1
    end
    #
    # Get data from all clusters in the pool
    fake_one.clusters.each do |one_cluster|
      cluster = ::One2Influx::Cluster.new(one_cluster[:xml], nil, hosts_xml)
      @points += cluster.serialize_as_points
      counter[:clusters] += 1
    end

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
    fake_one.datastores.each do |one_ds|
      ds = ::One2Influx::Datastore.new(one_ds[:xml], nil)
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
