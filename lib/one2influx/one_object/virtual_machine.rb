# Representation of ONE virtual machine
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

  # Computes percentage usage of memory for virtual machine.
  #  Values might go over 1.0 as there is an overhead
  # @return [float] current usage over max usage
  def get_MEMORY_PERC
    template_id = @doc.xpath('//TEMPLATE').first
    if template_id.nil? || template_id.content.nil?
      $LOG.error "Unable to get metric 'MEMORY_PERC' in #{self.class}."
      return
    end
    template_id = template_id.content
    template = OpenNebula::Template.new(OpenNebula::Template.build_xml(template_id), @client)
    rc = template.info
    raise rc.message if OpenNebula.is_error?(rc)

    doc = Nokogiri::XML(template.to_xml)
    ni_element = doc.xpath('//TEMPLATE/MEMORY').first
    puts @metrics
    if ni_element.nil? || @metrics[:MEMORY].nil?
      $LOG.error "Unable to get metric 'MEMORY_PERC' in #{self.class}."
      return
    end

    # Convert //TEMPLATE/MEMORY from MB to kB as //VM/CPU is in kB
    max_mem = ni_element.content.to_f * 1000.0

    @metrics[:MEMORY].to_f / max_mem
  end
end
