module One2Influx; end

require 'one2influx/config'
require 'one2influx/data'
require 'one2influx/influx'
require 'one2influx/one_object/one_object'
require 'one2influx/one_object/host'
require 'one2influx/one_object/datastore'
require 'one2influx/one_object/virtual_machine'
require 'one2influx/one_object/cluster'

# TODO remove
#require 'test/fake_data'
#require 'test/fake_one'

#require 'daemons'
require 'opennebula'
require 'nokogiri'