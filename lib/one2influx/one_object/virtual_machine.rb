class One2Influx::VirtualMachine < ::One2Influx::OneObject

  #
  # @param [string] xml representation of VM
  # @param [OpenNebula::Client] client connection link to ONE API
  # @param [One2Influx::Host] parent_host owner of this VM
  def initialize(xml, client, parent_host)
    # Load configuration
    @tag_names = $CFG.storage[:vm][:tags]
    @metric_names = $CFG.storage[:vm][:metrics]
    @custom_metric_names = $CFG.storage[:vm][:cust_metrics]

    # Assign tags inherited from parent host
    @tags = Hash.new
    $CFG.storage[:vm][:inh_tags].each do |name, value|
      @tags[name] = parent_host.tags[value.to_sym]
    end

    super(xml, client)
  end

  def get_REAL_CPU
    template_id = @doc.xpath('//TEMPLATE').first.content
    template = OpenNebula::Template.new(OpenNebula::Template.build_xml(template_id), @client)
    rc = template.info
    if OpenNebula.is_error?(rc)
      puts rc.message
      exit -1
    end
    doc = Nokogiri::XML(template.to_xml)

    # TODO kontrola jestli ma host CPU a v metrikach jestli je CPU
    value = (@metrics['CPU'].to_f / 100.0) * doc.xpath('//TEMPLATE/CPU').first.content.to_f
    (value * 100).round / 100.0
  end
end