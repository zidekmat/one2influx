require 'nokogiri'
require 'opennebula'

class One2Influx::Cluster < ::One2Influx::OneObject

  #
  # @param [string] xml representation of cluster
  # @param [OpenNebula::Client] client connection link to ONE API
  # @param [hash] hosts_xml xml representations of hosts in this cluster,
  #   in hash form {HOST_ID : XML_STRING}
  def initialize(xml, client, hosts_xml)
    # Load configuration
    @tag_names = $CFG.storage[:cluster][:tags]
    @metric_names = $CFG.storage[:cluster][:metrics]
    @custom_metric_names = $CFG.storage[:cluster][:cust_metrics]
    @hosts_xml = hosts_xml

    super(xml, client)
  end

  protected

  # Overrides OneObject init_metrics because cluster itself doesn't
  # have any own metrics, so they are gathered as sum of metrics of
  # hosts that belong to this cluster
  def init_metrics
    @metric_names.each do |metric|
      @metrics[metric.to_s] = 0
    end

    host_ids = @doc.xpath('//HOSTS/ID').map { |node| node.content }
    host_ids.each do |id|
      host_doc = Nokogiri::XML(@hosts_xml[id])
      @metric_names.each do |metric|
        host_metric = metric.split('HOSTS_')[1]
        unless host_metric.nil?
          ni_element = host_doc.css(host_metric).first
          if ni_element.nil?
            $LOG.error "Unable to get metric '#{metric}' in #{self.class}."
          else
            @metrics[metric.to_s] += ni_element.content.to_i
          end
        end
      end
    end

    # Get real percentage for cluster
    hosts_count = host_ids.length == 0 ? 1 : host_ids.length
    @metrics.each do |metric, value|
      if metric.to_s.include? 'CPU'
        @metrics[metric] = value / hosts_count
      end
    end
  end
end