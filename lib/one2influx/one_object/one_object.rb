require 'nokogiri'
require 'opennebula'

class One2Influx::OneObject

  attr_reader :tags, :metrics, :doc

  # Creates mapping between ONE XML names and InfluxDB names.
  #
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
          :name => metric_name,
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
        $LOG.error "Unable to get tag '#{one_name}' in #{self.class}."
      else
        @tags[influx_name.to_sym] = ni_element.content
      end
    end
  end

  def init_metrics
    @metric_names.each do |metric|
      ni_element = @doc.css(metric).first
      if ni_element.nil?
        $LOG.error "Unable to get metric '#{metric}' in #{self.class}."
      else
        @metrics[metric.to_sym] = ni_element.content
      end
    end
  end

  def init_custom_metrics
    @custom_metric_names.each do |metric|
      @metrics[metric.to_sym] = self.send("get_#{metric.to_s}")
    end
  end
end