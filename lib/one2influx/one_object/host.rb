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
#    xml ='<DATASTORES>
#<DS><ID>1</ID><FREE_MB>4545</FREE_MB></DS><DS><ID>0</ID><FREE_MB>45453</FREE_MB></DS>
#<DATASTORES/>'
#    @doc = Nokogiri::XML(xml)
    @doc.xpath('//DATASTORES/DS/ID').each do |ds|
      @datastores << ds.content
    end
  end
end