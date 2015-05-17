# Representation of ONE cluster
class One2Influx::Cluster < ::One2Influx::OneObject

  #
  # @param [string] xml representation of cluster
  # @param [OpenNebula::Client] client connection link to ONE API
  # @param [hash] oo_hosts hash in form {ID => OneObject::Host} of all hosts
  def initialize(xml, client, oo_hosts)
    # Load configuration
    @tag_names = $CFG.storage[:cluster][:tags]
    @metric_names = $CFG.storage[:cluster][:metrics]
    @custom_metric_names = $CFG.storage[:cluster][:cust_metrics]
    @hosts = oo_hosts

    super(xml, client)
  end

  private

  # @param [OneObject::Host] host host to fetch metric from
  # @param [string] metric metric to fetch
  # @raise [Exception] fetch error
  # @return metric from host
  def fetch_host_metric(host, metric)
      ni_element = host.doc.css(metric).first
      raise if ni_element.nil?

      ni_element.content.to_i
  end

  # Overrides OneObject init_metrics because cluster itself doesn't
  # have any own metrics, so they are gathered as sum of metrics of
  # hosts that belong to this cluster
  def init_metrics
    @metric_names.each do |metric|
      @metrics[metric.to_s] = 0
    end

    host_ids = @doc.xpath('//HOSTS/ID').map { |node| node.content }
    host_ids.each do |id|
      host = @hosts[id.to_sym]

      @metric_names.each do |metric|
        @metrics[metric.to_sym] ||= 0
        host_metric = metric.split('CLUSTER_')[1]
        next if host_metric.nil?

        if host.metrics.has_key? host_metric.to_sym
          @metrics[metric.to_sym] += host.metrics[host_metric.to_sym].to_i
        else
          ni_element = host.doc.css(host_metric).first
          if ni_element.nil?
            # Calculation of this metric would be misleading without this
            #   value, so I rather remove whole metric and log failure
            @metric_names = @metric_names.delete(metric)
            @metrics = @metrics.delete(metric.to_sym)
            $LOG.error "Unable to get metric '#{metric}' in #{self.class}." +
                           "XML parsing error in host ID=#{id}."
            next
          end

          @metrics[metric.to_sym] += ni_element.content.to_i
        end
      end
    end
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_MEM_USAGE / CLUSTER_MAX_MEM
  def get_CLUSTER_MEM_ALOC
    raise 'CLUSTER_MEM_USAGE is missing.' unless @metrics.has_key? :CLUSTER_MEM_USAGE
    raise 'CLUSTER_MAX_MEM is missing.' unless @metrics.has_key? :CLUSTER_MAX_MEM
    raise 'CLUSTER_MAX_MEM is 0.' if @metrics[:CLUSTER_MAX_MEM] == '0'

    (@metrics[:CLUSTER_MEM_USAGE].to_f / @metrics[:CLUSTER_MAX_MEM].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_USED_MEM / CLUSTER_MAX_MEM
  def get_CLUSTER_MEM_LOAD
    raise 'CLUSTER_USED_MEM is missing.' unless @metrics.has_key? :CLUSTER_USED_MEM
    raise 'CLUSTER_MAX_MEM is missing.' unless @metrics.has_key? :CLUSTER_MAX_MEM
    raise 'CLUSTER_MAX_MEM is 0.' if @metrics[:CLUSTER_MAX_MEM] == '0'

    (@metrics[:CLUSTER_USED_MEM].to_f / @metrics[:CLUSTER_MAX_MEM].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_MEM_ALOC / CLUSTER_MEM_LOAD
  def get_CLUSTER_MEM_WASTE
    raise 'CLUSTER_MEM_ALOC is missing.' unless @metrics.has_key? :CLUSTER_MEM_ALOC
    raise 'CLUSTER_MEM_LOAD is missing.' unless @metrics.has_key? :CLUSTER_MEM_LOAD

    mem_load = @metrics[:CLUSTER_MEM_LOAD] == 0 ? 0.001 : @metrics[:CLUSTER_MEM_LOAD]

    (@metrics[:CLUSTER_MEM_ALOC] / mem_load).round(2)
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_CPU_USAGE / CLUSTER_MAX_CPU
  def get_CLUSTER_CPU_ALOC
    raise 'CLUSTER_CPU_USAGE is missing.' unless @metrics.has_key? :CLUSTER_CPU_USAGE
    raise 'CLUSTER_MAX_CPU is missing.' unless @metrics.has_key? :CLUSTER_MAX_CPU
    raise 'CLUSTER_MAX_CPU is 0.' if @metrics[:CLUSTER_MAX_CPU] == '0'

    (@metrics[:CLUSTER_CPU_USAGE].to_f / @metrics[:CLUSTER_MAX_CPU].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_USED_CPU / CLUSTER_MAX_CPU
  def get_CLUSTER_CPU_LOAD
    raise 'CLUSTER_USED_CPU is missing.' unless @metrics.has_key? :CLUSTER_USED_CPU
    raise 'CLUSTER_MAX_CPU is missing.' unless @metrics.has_key? :CLUSTER_MAX_CPU
    raise 'CLUSTER_MAX_CPU is 0.' if @metrics[:CLUSTER_MAX_CPU] == '0'

    (@metrics[:CLUSTER_USED_CPU].to_f / @metrics[:CLUSTER_MAX_CPU].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] CLUSTER_CPU_ALOC / CLUSTER_CPU_LOAD
  def get_CLUSTER_CPU_WASTE
    raise 'CLUSTER_CPU_ALOC is missing.' unless @metrics.has_key? :CLUSTER_CPU_ALOC
    raise 'CLUSTER_CPU_LOAD is missing.' unless @metrics.has_key? :CLUSTER_CPU_LOAD

    cpu_load = @metrics[:CLUSTER_CPU_LOAD]
    if @metrics[:CLUSTER_CPU_LOAD] == 0
      cpu_load = 0.001
    end

    (@metrics[:CLUSTER_CPU_ALOC] / cpu_load).round(2)
  end
end