# Class for holding all configuration data, it is accessed by its only instance
#   in global variable $CFG
class One2Influx::Config

  ##############################################################################
  ## EDIT THIS PART IF NECESSARY                                              ##
  ##############################################################################

  # Data fetch interval. Allowed values are number of seconds, minutes, hours
  #  separated by space
  @@fetch_interval = '30 seconds'

  # OpenNebula connection configuration
  #####################################
  @@one = {
      # Login credentials separated by semicolon
      credentials: 'user:password',

      # XML_RPC endpoint where OpenNebula is listening
      endpoint: 'http://localhost:2633/RPC2'
  }

  # InfluxDB connection configuration
  ###################################
  @@influx = {
      # Whether to use basic authentication
      authenticate: false,

      # Login credentials separated by semicolon
      credentials: 'user:password',

      # InfluxDB HTTP API endpoint
      endpoint: 'http://localhost:8086',

      # Database name
      database: 'test',

      # Retention policy for records with the smallest granularity
      policy: 'ten_hours'
  }

  # Logging configuration
  #######################
  @@log = {
      # Level to use. Logger::INFO, Logger::WARN, Logger::ERROR are supported
      level: Logger::INFO,

      # Path to log file, when empty, one2influx.log is written into directory
      # where the binary is run from
      path: ''
  }

  # Configuration of metrics and tags to be stored to InfluxDB
  # Comment or uncomment metrics, tags or whole object depending on what you
  # want to store.
  ##########################################################################
  @@storage = {
      # Host
      host: {
          tags: {
              HOST_NAME: 'NAME',
              CLUSTER_ID: 'CLUSTER_ID',
              CLUSTER_NAME: 'CLUSTER',
              #HOST_STATE: 'STATE', # [int] host state
              #IM_MAD: 'IM_MAD',    # [string] monitoring manager driver
              #VM_MAD: 'VM_MAD',    # [string] virtualization manager driver
              #VN_MAD: 'VN_MAD',    # [string] virtual network manager driver
              DSS_IDS: ''  # [string] IDs of datastores that this host uses
                           #  encoded in form ,,ID_1,,ID_2...,,
          },
          metrics: [
              'MEM_USAGE', # [kB] memory requested by VMs
              'MAX_MEM',   # [kB] total memory available in host
              'FREE_MEM',  # [kB] free memory returned by probes
              'USED_MEM',  # [kB] memory used by all host processes over MAX_MEM
              'CPU_USAGE', # [%] usage of CPU calculated by ONE as the summatory
                           #     CPU requested by all VMs running in the host
              'MAX_CPU',   # [%] total CPU in the host (number of cores * 100)
              'FREE_CPU',  # [%] free CPU as returned by the probes
              'USED_CPU'   # [%] CPU used by all host processes over a total
                           #     of # cores * 100
          ],
          cust_metrics: []
      },
      # Virtual machine
      vm:   {
          tags: {
              CLUSTER_ID: 'CLUSTER_ID',
              CLUSTER_NAME: 'CLUSTER_NAME',
              HOST_ID: 'HOST_ID',
              HOST_NAME: 'HOST_NAME',
              VM_NAME: 'NAME',
              UID: 'UID',            # [int] user's ID
              GID: 'GID',            # [int] group's ID
              UNAME: 'UNAME',        # [string] user's name
              GNAME: 'GNAME',        # [string] group's name
              #VM_STATE: 'STATE',     # [int] virtual machine state
              #LCM_STATE: 'LCM_STATE' # [int] substates for ACTIVE state
          },
          metrics: [
              'MEMORY', # [kB] memory consumption
              'CPU',    # [%] 1 VCPU consumed (two fully consumed cpu is 200)
              #'NET_TX', # [B] sent to the networ
              #'NET_RX'  # [B] received from the network
          ],
          cust_metrics: [
              #'MEMORY_PERC' # Computes percentage usage of memory for VM
          ]

      },
      # Datastore
      ds:   {
          tags: {
              DS_NAME: 'NAME',
              CLUSTER_ID: 'CLUSTER_ID',
              CLUSTER_NAME: 'CLUSTER',
              TM_MAD: 'TM_MAD',  # [shared|ssh|qcow2|vmfs|ceph|lvm|fs_lvm|dev]
                                 #  transfer manager
              DS_MAD: 'DS_MAD',  # [fs|vmfs|lvm|ceph|dev] datastore type
              UID: 'UID',        # [int] user's ID
              GID: 'GID',        # [int] group's ID
              UNAME: 'UNAME',    # [string] user's name
              GNAME: 'GNAME',    # [string] group's name
              HOSTS_IDS: ''      # [string] IDs of hosts that are using this
                                 #  datastore encoded in form ,,ID_1,,ID_2...,,
          },
          metrics: [
              'TOTAL_MB', # [MB] total space available in datastore
              'FREE_MB',  # [MB] free space
              'USED_MB'   # [MB] used space
          ],
          cust_metrics: []
      },
      # Cluster
      cluster: {
          tags: {
              CLUSTER_NAME: 'NAME'
          },
          metrics: [
              'CLUSTER_MEM_USAGE', # [kB] memory requested by all VMs in cluster
              'CLUSTER_MAX_MEM',   # [kB] total memory available in all hosts
              'CLUSTER_FREE_MEM',  # [kB] free memory of all hosts returned
                                   #  by probes
              'CLUSTER_USED_MEM',  # [kB] memory used by all processes of all
                                   #  hosts over MAX_MEM
              'CLUSTER_CPU_USAGE', # [%] usage of CPU calculated by ONE as the
                                   #  sum of CPU requested by all VMs running
                                   #  in the cluster
              'CLUSTER_MAX_CPU',   # [%] total CPU in the cluster
                                   #  (number of cores * 100)
              'CLUSTER_FREE_CPU',  # [%] free CPU as returned by the probes
              'CLUSTER_USED_CPU'   # [%] CPU used by all processes of all hosts
                                   #  over a total of # cores * 100
          ],
          cust_metrics: []
      }
  }

  ##############################################################################
  ## DO NOT EDIT BELOW THIS LINE                                              ##
  ##############################################################################

  attr_reader :sec_interval
  # @@fetch_interval in seconds
  @sec_interval = 0

  public
  # Group of getter methods for configuration class variables
  def one
    @@one
  end

  def influx
    @@influx
  end

  def storage
    @@storage
  end

  # Initializes logging, converts fetch interval from human readable form,
  #   adds tag ID to all metrics and converts VM's tags from human readable form
  def initialize
    log_path = @@log[:path] + 'one2influx.log'
    begin
      $LOG = Logger.new(log_path, 'daily', 30)
    rescue Exception => e
      raise "Unable to create log file. #{e.message}"
    end
    $LOG.level = @@log[:level]

    convert_to_sec
    prepare_storage_ids
    prepare_vm_config
  end

  # Checks it is possible to connect to ONE with provided credentials.
  def is_one_available?
    begin
      client = OpenNebula::Client.new(@@one[:credentials], @@one[:endpoint])
    rescue Exception => e
      $LOG.error "Unable to connect to ONE with message: #{e.message}"
      return false
    end

    version = client.get_version
    # Try to get ONE version just to check if it's possible to connect to ONE
    if version.is_a? OpenNebula::Error
      $LOG.error 'Unable to find out ONE version with message: '+version.message
      return false
    end
    $LOG.info 'Connection with ONE verified.'

    return true
  end

  private

  # Adds obligatory ID tag to all storage objects in form OBJ_ID, where OBJ is
  # object name. Therefore OneObjects will always have at least one tag, ID.
  def prepare_storage_ids
    @@storage.each do |object, values|
      id_name = "#{object.to_s.upcase}_ID"
      values[:tags][id_name.to_sym] = 'ID'
    end
  end

  # XML with virtual machine monitoring doesn't contain tags CLUSTER_ID,
  # CLUSTER_NAME, HOST_ID and HOST_NAME so it needs to be loaded from the host
  # running that VM.
  # Therefore these tags are handled differently and needs to be separated from
  # the rest into @@storage[:vm][:inh_tags]
  def prepare_vm_config
    inh_tags = %i(CLUSTER_ID CLUSTER_NAME HOST_ID HOST_NAME)
    @@storage[:vm][:inh_tags] = @@storage[:vm][:tags].clone

    # Get inherited tags into special hash for VMs only
    @@storage[:vm][:inh_tags].keep_if do |key, value|
      inh_tags.include? key
    end
    # Remove them from original hash
    @@storage[:vm][:inh_tags].each do |key, value|
      @@storage[:vm][:tags].delete(key)
    end
  end

  # Converts local variable human_interval to seconds
  #  and stores in sec_interval
  def convert_to_sec
    duration = @@fetch_interval.split(' ')

    if duration.length != 2
      raise "Invalid @@fetch_interval(=#{@@fetch_interval}) in config.rb."
    end

    case duration[1]
      when /seconds?/
        multiply = 1
      when /minutes?/
        multiply = 60
      when /hours?/
        multiply = 3600
      else
        raise "Invalid @@fetch_interval(=#{@@fetch_interval}) in config.rb."
    end

    @sec_interval = duration[0].to_i * multiply
  end
end
