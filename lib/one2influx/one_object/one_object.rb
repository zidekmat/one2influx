# 'Abstract' class for OpenNebula's objects representation
class One2Influx::OneObject

  attr_reader :tags, :metrics, :doc

  # Creates mapping between ONE XML names and InfluxDB storage names.
  # Loads all tags, metrics and custom metrics from given XML.
  # @param [string] xml representation of OneObject
  # @param [OpenNebula::Client] client connection link to ONE API
  def initialize(xml, client)
    @tags ||= Hash.new
    @metrics ||= Hash.new
    @doc ||= Nokogiri::XML(xml)
    @client = client

    init_tags
    init_metrics
    init_custom_metrics
  end

  # Serialize OneObject instance to InfluxDB point form
  def serialize_as_points
    points = []
    @metrics.each do |metric_name, metric_value|
      points << {
          :measurement => metric_name,
          :tags => @tags,
          :fields => {
              :value => metric_value.to_f
          }
      }
    end

    return points
  end

  # Called in case of misconfiguration and invalid custom metric method
  # was called
  def method_missing(name, *args, &block)
    $LOG.error "Invalid method '#{name}' was called from #{self.class}! " #+
      #  "Stacktrace: #{e.backtrace}"
  end

  protected

  def init_tags
    @tag_names.each do |influx_name, one_name|
      ni_element = @doc.css(one_name).first
      if ni_element.nil?
        $LOG.error "Unable to get tag '#{one_name}' in #{self.class}." +
            'XML parsing error.'
      else
        @tags[influx_name.to_sym] = ni_element.content
      end
    end
  end

  def init_metrics
    @metric_names.each do |metric|
      ni_element = @doc.css(metric).first
      if ni_element.nil?
        $LOG.error "Unable to get metric '#{metric}' in #{self.class}." +
            'XML parsing error.'
      else
        @metrics[metric.to_sym] = ni_element.content
      end
    end
  end

  def init_custom_metrics
    @custom_metric_names.each do |metric|
      begin
        @metrics[metric.to_sym] = self.send("get_#{metric.to_s}")
      rescue Exception => e
        $LOG.error "Unable to get metric '#{metric}'. #{e.message}"
      end
    end
  end
end