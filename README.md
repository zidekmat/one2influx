# one2influx

One2influx is small ruby daemon for getting monitoring data from [OpenNebula's XML-RPC API](http://docs.opennebula.org/4.12/integration/system_interfaces/api.html) and storing it to [InfluxDB](http://influxdb.com/). It needs Ruby 2+ to run.

### Installation
For Debian 8:
```bash
$ sudo apt-get install ruby ruby-dev libghc-zlib-dev -y
$ git clone https://github.com/zidekmat/one2influx.git
$ cd one2influx && gem install bundle && bundle install
```
Then just set up your connection with ONE and InfluxDB and run
```bash
$ ./bin/one2influx &
```

### Settings
Can be found in ***lib/one2influx/config.rb***. By default logs are stored in the directory from which the script was executed.

### Testing
You can run this without working ONE instance. Executable ***test/one2influx_fake*** will provide you with some testing XML data that can be modified in ***test/fake_lib/fake_one.rb***.