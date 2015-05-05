require 'gyoku'
require 'nokogiri'
require 'rubystats'

class One2Influx::FakeOne

  attr_reader :clusters, :datastores, :hosts

  public

  def initialize
    @count = {
        hosts: 300,
        vms: 600,
        dss: 500,
        clusters: 100,
        groups: 300
    }

    init_clusters
    init_dss
    init_hosts
  end

  def get_vms(host_id)
    vms = []
    @hosts[host_id][:hash][:HOST][:VMS].each do |hash|
      id = hash[:ID]
      vm = {
          VM: {
              ID: id,
              UID: id,
              GID: id % @count[:groups],
              UNAME: "user-#{id}",
              GNAME: '',
              NAME: "vm-#{id}",
              MEMORY: Random.new.rand(2..6)*100000,
              CPU: Random.new.rand(1..100)/100,
              NET_TX: Random.new.rand(2..9)*10000,
              NET_RX: Random.new.rand(2..9)*10000
          }
      }
      vms << Gyoku.xml(vm, {:key_converter => :none})
    end

    vms
  end

  private

  def init_hosts
    all_vms = (0..@count[:vms]).to_a
    all_vms.shuffle!
    metrics = {
        MEM_USAGE: {
            gen: Rubystats::NormalDistribution.new(Random.new.rand(8..20)*100000, Random.new.rand(1..7)*100000)
        },
        USED_MEM: {
            gen: Rubystats::NormalDistribution.new(Random.new.rand(8..20)*100000, Random.new.rand(1..7)*100000)
        },
        CPU_USAGE: {
            gen: Rubystats::NormalDistribution.new(Random.new.rand(2..6)*100, 100)
        },
        USED_CPU: {
            gen: Rubystats::NormalDistribution.new(Random.new.rand(2..6)*100, 100)
        }
    }
    metrics.each do |name, m|
      metrics[name.to_sym][:values] = Array.new(@count[:hosts]) { m[:gen].rng.round }
    end
    max_mem = metrics[:USED_MEM][:values].max
    metrics[:FREE_MEM] = Array.new(@count[:hosts]) do |i|
      max_mem - metrics[:USED_MEM][:values][i]
    end
    max_cpu = metrics[:USED_CPU][:values].max
    metrics[:FREE_CPU] = Array.new(@count[:hosts]) do |i|
      max_cpu - metrics[:USED_CPU][:values][i]
    end

    hosts = []
    for id in 0..@count[:hosts] do
      cluster_id = id % @count[:clusters]
      # Assign few datastores
      datastores = []
      Random.new.rand(3..10).times do
        ds = @datastores.sample[:hash][:DATASTORE]
        datastores << {
            ID: ds[:ID],
            FREE_MB: ds[:FREE_MB],
            TOTAL_MB: ds[:TOTAL_MB],
            USED_MB: ds[:USED_MB]
        }
      end
      vms = []
      # Add remaining VMs to last host
      if id == @count[:hosts]
        vms += all_vms.map { |x| { ID: x } }
      else
        # Add up to three VMs to this host
        Random.new.rand(0..3).times do
          vms << {
              ID: all_vms.shift
          }
        end
      end
      hash = {
          HOST: {
              ID: id,
              NAME: "host-#{id}",
              CLUSTER_ID: cluster_id,
              CLUSTER: "cluster-#{cluster_id}",
              HOST_SHARE: {
                  MEM_USAGE: metrics[:MEM_USAGE][:values][id],
                  MAX_MEM: max_mem,
                  FREE_MEM: metrics[:FREE_MEM][id],
                  USED_MEM: metrics[:USED_MEM][:values][id],
                  CPU_USAGE: metrics[:CPU_USAGE][:values][id],
                  MAX_CPU: max_cpu,
                  FREE_CPU: metrics[:FREE_CPU][id],
                  USED_CPU: metrics[:USED_CPU][:values][id],
                  DATASTORES: { DS: datastores }
              },
              VMS: vms
          }
      }
      hosts << {
          xml: Gyoku.xml(hash, {:key_converter => :none}),
          hash: hash
      }
    end

    @hosts = hosts

    hosts
  end

  def init_clusters
    @clusters = []
    for id in 0..99 do
      hash = {
        CLUSTER: {
          ID: id,
          NAME: "cluster-#{id}"
        }
      }
      @clusters << {
          xml: Gyoku.xml(hash, {:key_converter => :none}),
          hash: hash
      }
    end

  end

  def init_dss
    ds_mad = %w(fs vmfs lvm ceph dev)
    tm_mad = %w(shared ssh qcow2 vmfs ceph lvm fs_lvm dev)
    @datastores = []
    for id in 0..500 do
      total_mb = Random.new.rand(1000..500000)
      free_mb = Random.new.rand(1000..total_mb)
      cluster = @clusters.sample[:hash][:CLUSTER]
      hash = {
          DATASTORE: {
              ID: id,
              NAME: "datastore-#{id}",
              CLUSTER_ID: cluster[:ID],
              CLUSTER: cluster[:NAME],
              TM_MAD: tm_mad.sample,
              DS_MAD: ds_mad.sample,
              UID: id,
              GID: id % @count[:groups],
              UNAME: "user-#{id}",
              GNAME: '',
              FREE_MB: free_mb,
              TOTAL_MB: total_mb,
              USED_MB: total_mb - free_mb
          }
      }
      @datastores << {
          xml: Gyoku.xml(hash, {:key_converter => :none}),
          hash: hash
      }
    end
  end
end