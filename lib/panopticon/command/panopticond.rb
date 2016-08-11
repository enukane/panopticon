module Panopticon
  require "panopticon/log"

  class Daemon
    DEFAULT_CONFIG_PATH="/etc/panopticon.conf"

    DEFAULT_API_PORT=8080

    DEFAULT_IFNAME="wlan0"
    DEFAULT_CAPTURE_PATH="/cap"
    DEFAULT_LOG_FILE="/var/log/panopticond.log"

    def self.default_options
      {
        # config file (exclusive)
        :config_file => DEFAULT_CONFIG_PATH,

        # daemon parameters
        :port => DEFAULT_API_PORT,

        # capture parameters
        :ifname => DEFAULT_IFNAME,
        :capture_path => DEFAULT_CAPTURE_PATH,

        # log
        :log_file => DEFAULT_LOG_FILE,
      }
    end

    def initialize arg={}
      @arg = arg

      @config_file = arg[:config_file]

      @arg = read_config(@config_file)
    end

    def run
      Panopticon::APIServer.run!(@arg)
    end

    def read_config path
      # notimp
      @arg
    end
  end
end
