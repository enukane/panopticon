module Panopticon
  require "json"
  require "thread"

  require "panopticon/log"
  require "panopticon/wlan_capture"

  class WlanControl
    DEFAULT_IFNAME = "wlan0"
    DEFAULT_CAPTURE_PATH = "/cap"

    STATE_INIT = :INIT
    STATE_RUNNING = :RUNNING
    STATE_STOP = :STOP

    def self.default_options
      return  {
        :ifname => DEFAULT_IFNAME,
        :capture_path => DEFAULT_CAPTURE_PATH,
      }
    end

    def initialize args={}
      @th_capture = nil
      @wlan_capture = nil
      @state = STATE_INIT

      @ifname = args[:ifname] || DEFAULT_IFNAME
      $log.debug("hogeeee #{@ifname} #{args[:ifname]}")
      @capture_path = args[:capture_path] || DEFAULT_CAPTURE_PATH

      @hostname = `hostname`
    end

    def disk_info
      line = `df`.split("\n")[1].split  # assumes first line to be "/"
      size = line[1].to_i * 512
      used = line[2].to_i * 512

      return {:size => size, :used => used }
    end

    def memory_info
      if File.exists?("/proc/meminfo")
        # linux or bsd
        return memory_info_from_proc
      else
        # mac os x ?
        return memory_info_from_mac
      end
    end

    def memory_info_from_proc
      total = 0
      free = 0
      used = 0
      File.open("/proc/meminfo") do |file|
        total = file.gets.split[1].to_i
        free = file.gets.split[1].to_i
        used = total - free
      end

      return {:size => total, :used => used}
    end

    def memory_info_from_mac
      _, total = `sysctl hw.memsize`.split.map{|n| n.to_i}

      used = 0
      app_mem = 0
      comp_mem = 0
      file_backed_mem = 0
      `vm_stat`.split("\n").each do |line|
        match = line.match(/^Anonymous pages: *(\d+)\.$/)
        if match
          app_mem = match[1].to_i * 4096
        end

        match = line.match(/^Pages occupied by compressor: *(\d+)\.$/)
        if match
          comp_mem = match[1].to_i * 4096
        end

        match = line.match(/^File-backed pages: *(\d+)\.$/)
        if match
          file_backed_mem = match[1].to_i * 4096
        end
      end

      used = (app_mem + comp_mem + file_backed_mem)

      return {:size => total, :used => used}
    end

    def cpu_info
      if File.exists?("/proc/stat")
        return cpu_info_from_proc
      else
        return cpu_info_from_mac
      end
    end

    def cpu_info_from_proc
      used = 0

      current_cpu_info = []
      File.open("/proc/stat") do |file|
        current_cpu_info = file.gets.split[1..4].map{|elm| elm.to_i}
      end

      if @prev_cpu_info == nil
        @prev_cpu_info = current_cpu_info
        return 0
      end

      usage_sub = current_cpu_info[0..2].inject(0){|sum, elm| sum += elm} -
        @prev_cpu_info[0..2].inject(0){|sum, elm| sum += elm}
      total_sub = current_cpu_info.inject(0){|sum, elm| sum += elm} -
        @prev_cpu_info.inject(0){|sum, elm| sum += elm}

      @prev_cpu_info = current_cpu_info

      used = ((usage_sub.to_f * 100) / total_sub)

      return used
    end

    def cpu_info_from_mac
      line = `top | head -4 | grep CPU`
      match = line.match(/^CPU usage: *(\d+\.\d+)% user, *(\d+\.\d+)% sys, *(\d+\.\d+)% idle $/)
      return 0.0 unless match

      user = match[1].to_f
      sys = match[2].to_f
      idle = match[3].to_f
      used = 100 - idle

      return used
    end

    def capture_file_info
      filesize = 0
      duration = 0

      if @wlan_capture
        filesize = @wlan_capture.filesize
        duration = @wlan_capture.duration
      end

      return {
        :filename => @filename,
        :filesize => filesize,
        :duration => duration,
      }
    end

    def wlan_info
      info = {
        :current_channel =>     0,
        :channel_walk =>        0,
        :utilization =>         0,
        :utilization_channel => 0,
      }

      unless @state == STATE_RUNNING
        return info
      end

      if @wlan_capture.nil?
        $log.err("state mismatch (state = #{@state} <=> capture is running");
        return
      end

      info[:current_channel] = @wlan_capture.current_channel
      info[:channel_walk] = @wlan_capture.channel_walk
      info[:utilization] = @wlan_capture.utilization
      info[:utilization_channel] = @wlan_capture.utilization_channel

      return info
    end

    def generate_filename
      return "#{Time.now.strftime("%Y%m%d%H%m%S")}_#{@ifname}_#{$$}.pcapng"
    end

    # request handler for API
    def start_capture arg
      $log.info("starting new capture")

      if @state == STATE_RUNNING
        $log.warn("WlanCapture instance is already running")
        return
      end

      if @th_capture
        $log.warn("capture thread is already running, terminate it first")
        return
      end

      if @wlan_capture
        $log.warn("capture instance is running, teminate it first")
        return
      end

      $log.info("starting new capture instance")
      @wlan_capture = Panopticon::WlanCapture.new(@ifname)

      # start capturing
      filename = generate_filename()
      @th_capture = Thread.new do
        @wlan_capture.run_capture("#{@capture_path}/#{filename}")
      end
      $log.info("started new capture at #{filename}")

      # move state
      @state = STATE_RUNNING
      @filename = filename
    end

    def stop_capture
      if @state == STATE_INIT or @state == STATE_STOP
        $log.err("stopping not runnning capture instance")
        return
      end

      if @wlan_capture
        @wlan_capture.stop_capture
      end

      if @th_capture and @th_capture.alive?
        $log.info("stopping capture thread")
        @th_capture.join
      end

      @wlan_capture = nil
      @th_capture = nil

      @state = STATE_STOP
    end

    def change_channels arg
    end

    def get_config
    end

    def get_status
      @cached_disk_info = disk_info()
      @cached_memory_info = memory_info()
      @cached_cpu_info = cpu_info()
      @cached_file_info = capture_file_info()
      @cached_wlan_info = wlan_info()

      return {
        :date         => Time.now.to_i,
        :hostname     => @hostname,
        :disk_size    => @cached_disk_info[:size],
        :disk_used    => @cached_disk_info[:used],
        :memory_size  => @cached_memory_info[:size],
        :memory_used  => @cached_memory_info[:used],
        :cpu_usage    => @cached_cpu_info,

        :state        => @state,
        :filename     => @filename,
        :filesize     => @cached_file_info[:filesize],
        :duration     => @cached_file_info[:duration],

        :current_channel => @cached_wlan_info[:current_channel],
        :channel_walk => @cached_wlan_info[:channel_walk],
        :utilization  => @cached_wlan_info[:utilization],
        :utilization_channel => @cached_wlan_info[:utilization_channel],
      }
    end
  end
end
