# Used for storing data to InfluxDB through HTTP API
class One2Influx::Influx

  # Initializes class Influx.
  # @raise [Exception] in case of error while getting UUID
  def initialize
    @authenticate = $CFG.influx[:authenticate]
    if @authenticate
      creds = $CFG.influx[:credentials].split(':')
      raise 'InfluxDB credentials have invalid form!' if creds.length != 2
      @user = creds[0]
      @pass = creds[1]
    end
    uri = URI.parse($CFG.influx[:endpoint])
    @host = uri.host
    @port = uri.port
    @db = $CFG.influx[:database]
    @retention_policy = $CFG.influx[:policy]
  end


  # @param [hash] points returned by OneObject.serialize_as_points
  # @raise [Exception] in case of unsuccessful storing
  def store(points)
    # Split points by 2500 for better performance
    points.each_slice(2500).to_a.each do |slice|
      # Default InfluxDB payload form
      payload = {
          :database => @db,
          :retentionPolicy => @retention_policy,
          :points => slice
      }
      # puts "Total number of points is #{points.length}"

      # Create InfluxDB write request
      req = Net::HTTP::Post.new(
          '/write',
          initheader = {
              'Content-Type' => 'application/json'
          }
      )

      req.body = payload.to_json
      response = make_request(req)

      if (not response.nil?) && (response.code != '204')
        raise 'Failed to store data to InfluxDB. Received HTTP code ' +
                  "#{response.code}, body: #{response.body}"
      end
      $LOG.info "Successfully stored #{slice.length} data points."
    end
  end

  # Checks whether InfluxDB connection is possible, database @db exists
  # and @retention_policy exists.
  # @return [boolean]
  def db_exists?
    uri = URI('/query')
    query = {:q => "SHOW RETENTION POLICIES #{@db}"}
    uri.query = URI.encode_www_form(query)

    req = Net::HTTP::Get.new(uri.to_s)

    response =  make_request(req)

    # Was request successful?
    if response.nil?
      return false
    end

    # Check for invalid HTTP response codes
    if response.code.to_i == 401
      $LOG.error "Unauthorized user '#{@user}', unable to verify connection" +
                     ' to InfluxDB.'
      return false
    elsif response.code.to_i != 200
      $LOG.error 'Failed to store data to InfluxDB. Received HTTP code ' +
                     "#{response.code}, body: #{response.body}"
      return false
    end

    # Parse response
    begin
      response = JSON.parse(response.body)
    rescue JSON::ParserError => e
      $LOG.error 'Unable to parse InfluxDB response, while verifying ' +
                     "connection to database '#{@db}': #{e}. " +
                     "Received: #{response.body}"
      return false
    end

    begin
      if response['results'][0].has_key? 'error'
        $LOG.error "Unable to verify connection to InfluxDB database '#{@db}'" +
                       " with message: #{response['results'][0]['error']}"
        return false
      end

      response['results'][0]['series'][0]['values'].each do |policy|
        if policy[0] == @retention_policy
          $LOG.info "Connection to InfluxDB database '#{@db}' with retention " +
                        "policy '#{@retention_policy}' verified."
          return true
        end
      end
    rescue Exception
      # Handle index out of bounds etc. exceptions
      $LOG.error "Unable to verify connection to InfluxDB database '#{@db}'. " +
                     'Invalid InfluxDB response format.'
      return false
    end
    $LOG.error "InfluxDB database '#{@db}' does not contain supplied " +
                   "retention policy '#{@retention_policy}'."

    return false
  end

  private

  # @param [Net::HTTP::Post|Net::HTTP::Get] request
  # @raise [Exception] Net::*
  # @return [Net::HTTPResponse]
  def make_request(request)
    if @authenticate
      request.basic_auth @user, @pass
    end

    retries = 4
    begin
      http = Net::HTTP.new(@host, @port)
      http.read_timeout = 2
      response = http.start do |http|
        http.request(request)
      end
    rescue Exception => e
      if retries < 0 then
        if e.is_a? Net::ReadTimeout
          raise 'Unable to post data to InfluxDB for 5th time! ' +
                    'Timed out, possibly not stored.'
        else
          raise 'Unable to post data to InfluxDB for 5th time! ' +
                    "Error: #{e.message}."
        end
        return nil
      else
        $LOG.warn "Unable to post data to InfluxDB! Trying #{retries+1} more " +
                      "times. Error: #{e.message}."
        retries -= 1
        sleep(0.01)
        retry
      end
    end

    return response
  end
end