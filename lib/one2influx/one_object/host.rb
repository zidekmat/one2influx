# Representation of ONE host
class One2Influx::Host < ::One2Influx::OneObject

  attr_reader :datastores

  #
  # @param [string] xml representation of host
  # @param [OpenNebula::Client] client connection link to ONE API
  def initialize(xml, client)
    # Load configuration
    @tag_names = $CFG.storage[:host][:tags]
    @metric_names = $CFG.storage[:host][:metrics]
    @custom_metric_names = $CFG.storage[:host][:cust_metrics]


    @doc = Nokogiri::XML(xml)
    @tags = Hash.new
    load_datastores
    if @tag_names.has_key? :DSS_IDS
      @tag_names.delete :DSS_IDS
      unless @datastores.empty?
        @tags[:DSS_IDS] = ',,' + @datastores.join(',,') + ',,'
      end
    end

    super(xml, client)
  end

  #
  # @return [array] IDs of VMs
  def vms
    @doc.xpath('//VMS/ID').map do |node|
      node.content
    end
  end

  private

  # Initializes @datastores array of IDs for datastores associated with
  #  this host
  def load_datastores
    @datastores = []
    @doc.xpath('//DATASTORES/DS/ID').each do |ds|
      @datastores << ds.content
    end
  end

  # @raise [Exception] calculation error
  # @return [float] MEM_USAGE / MAX_MEM
  def get_HOST_MEM_ALOC
    raise 'MEM_USAGE is missing.' unless @metrics.has_key? :MEM_USAGE
    raise 'MAX_MEM is missing.' unless @metrics.has_key? :MAX_MEM
    raise 'MAX_MEM is 0.' if @metrics[:MAX_MEM] == '0'

    (@metrics[:MEM_USAGE].to_f / @metrics[:MAX_MEM].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] USED_MEM / MAX_MEM
  def get_HOST_MEM_LOAD
    raise 'USED_MEM is missing.' unless @metrics.has_key? :USED_MEM
    raise 'MAX_MEM is missing.' unless @metrics.has_key? :MAX_MEM
    raise 'MAX_MEM is 0.' if @metrics[:MAX_MEM] == '0'

    (@metrics[:USED_MEM].to_f / @metrics[:MAX_MEM].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] HOST_MEM_ALOC / HOST_MEM_LOAD
  def get_HOST_MEM_WASTE
    raise 'HOST_MEM_ALOC is missing.' unless @metrics.has_key? :HOST_MEM_ALOC
    raise 'HOST_MEM_LOAD is missing.' unless @metrics.has_key? :HOST_MEM_LOAD

    mem_load = @metrics[:HOST_MEM_LOAD] == 0 ? 0.001 : @metrics[:HOST_MEM_LOAD]

    (@metrics[:HOST_MEM_ALOC] / mem_load).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] CPU_USAGE / MAX_CPU
  def get_HOST_CPU_ALOC
    raise 'CPU_USAGE is missing.' unless @metrics.has_key? :CPU_USAGE
    raise 'MAX_CPU is missing.' unless @metrics.has_key? :MAX_CPU
    raise 'MAX_CPU is 0.' if @metrics[:MAX_CPU] == '0'

    (@metrics[:CPU_USAGE].to_f / @metrics[:MAX_CPU].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] USED_CPU / MAX_CPU
  def get_HOST_CPU_LOAD
    raise 'USED_CPU is missing.' unless @metrics.has_key? :USED_CPU
    raise 'MAX_CPU is missing.' unless @metrics.has_key? :MAX_CPU
    raise 'MAX_CPU is 0.' if @metrics[:MAX_CPU] == '0'

    (@metrics[:USED_CPU].to_f / @metrics[:MAX_CPU].to_f).round(4)*100
  end

  # @raise [Exception] calculation error
  # @return [float] HOST_CPU_ALOC / HOST_CPU_LOAD
  def get_HOST_CPU_WASTE
    raise 'HOST_CPU_ALOC is missing.' unless @metrics.has_key? :HOST_CPU_ALOC
    raise 'HOST_CPU_LOAD is missing.' unless @metrics.has_key? :HOST_CPU_LOAD

    cpu_load = @metrics[:HOST_CPU_LOAD]
    if @metrics[:HOST_CPU_LOAD] == 0
      cpu_load = 0.001
    end

    (@metrics[:HOST_CPU_ALOC] / cpu_load).round(2)
  end
end