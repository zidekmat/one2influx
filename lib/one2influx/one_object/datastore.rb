# Representation of ONE datastore
class One2Influx::Datastore < ::One2Influx::OneObject

  #
  # @param [string] xml representation of datastore
  # @param [OpenNebula::Client] client connection link to ONE API
  def initialize(xml, client)
    # Load configuration
    @tag_names = $CFG.storage[:ds][:tags]
    @metric_names = $CFG.storage[:ds][:metrics]
    @custom_metric_names = $CFG.storage[:ds][:cust_metrics]

    # Parsing HOST_ID_X as normal tag_name would cause error
    if @tag_names.has_key? :HOSTS_IDS
      @tag_names.delete :HOSTS_IDS
    end

    super(xml, client)
  end

  # Add tag HOSTS_IDS a string containing IDs of all hosts associated
  # with this datastore in form for each host associated with this datastore in
  # form ,,ID_1,,ID_2...,,
  # @param [array] hosts array of hosts IDs that are using this datastore
  def add_hosts_ids(hosts)
    unless hosts.empty?
      @tags[:HOSTS_IDS] = ',,' + hosts.join(',,') + ',,'
    end
  end
end