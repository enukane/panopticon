module Panopticon
  require "open3"
  require "panopticon/wlan_utilization"

  class WlanCapture
    attr_reader :duration, :current_channel, :filesize, :channel_walk, :utilization, :utilization_channel
    CHAN = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
            34, 36, 38, 40, 42, 44, 46, 48,
            52, 56, 60, 64,
            100, 104, 108, 112, 116,
            120, 124, 128, 132, 136, 140,
            149, 153, 157, 161, 165]
    LIMIT_IDX=CHAN.length

    DEFAULT_IFNAME="wlan0"
    DEFAULT_INTERVAL=1

    def initialize ifname=DEFAULT_IFNAME, channels=CHAN, interval = DEFAULT_INTERVAL
      @th_shark = nil
      @th_capture = nil
      @black_list = []

      @ifname = ifname || DEFAULT_IFNAME
      @channels = channels || CHAN
      @interval = interval || DEFAULT_INTERVAL

      init_status()

      @wlan_utilization = Panopticon::WlanUtilization.new(@ifname)
    end

    def run_capture fpath
      init_device()
      init_status()
      start_time = Time.now.to_i

      stdin, stdout, stderr, @th_tshark = *Open3.popen3(
        "tshark -i #{@ifname} -F pcapng -w #{fpath}")

      while @th_tshark.alive?
        sleep 1

        # update status
        @duration = Time.now.to_i - start_time
        @filesize = File.size?(fpath) || 0

        # do something here to run before channel transition
        ary = @wlan_utilization.current_data()
        @utilization_channel = ary[0]
        @utilization = ary[3]

        prev_channel = @current_channel
        @current_chanenl = move_channel(@current_channel, @channels)
        @channel_walk += 1
        $log.debug("channel moved to #{@current_channel} from #{prev_channel} (dur=#{@duration}, size=#{@filesize}, walk=#{@channel_walk}, utilization=#{@utilization} uch=#{@utilization_channel})")
      end
    rescue => e
      $log.warn("run_capture detected unknown error (#{e})")
    end

    def stop_capture
      if @th_tshark == nil
        $log.err("tried to kill tshark, but it's not executed? (or already dead?)")
        return
      end

      Process.kill("INT", @th_tshark.pid)
    end

    def modify_channels channels
      @channels = channels
    end

    private
    def init_status
      @duration = 0
      @current_channel = @channels[0] || 1
      @filesize = 0
      @channel_walk = 0
    end

    def init_device
      unless @ifname.match(/^wlan\d+$/)
        $log.debug("non-wlan device skips device initialization")
        return
      end

      unless system("ip link set #{@ifname} down")
        raise "failed to turn down #{@ifname}"
      end
      unless system("iw #{@ifname} set monitor fcsfail otherbss control")
        raise "failed to set #{@ifname} to monitor mode"
      end
      unless system("ip link set #{@ifname} up")
        raise "failed to turn up #{@ifname}"
      end
      unless system("iw wlan0 set channel #{@current_channel}")
        raise "failed to set channel #{@current_channel} on #{@ifname}"
      end
    end

    def move_channel current, channels
      unless @ifname.match(/^wlan\d+$/)
        $log.debug("non-wlan device skips channel transition")
        return
      end

      next_channel = pick_channel(current, channels)

      while !system("iw #{@ifname} set channel #{next_channel}")
        # what if we got unplugged ifname? => should we die?
        $log.debug("channel transition failed, added to black list (channel=#{next_channel})")
        @black_list << next_channel
        sleep 1
        next_channel = pick_channel(next_channel)
      end

      @current_channel = next_channel
    end

    def pick_channel current, channels
      idx = channels.index(current)
      idx += 1
      next_channel = channels[idx % channels.length] || 1

      # we have black list
      while @black_list.include?(next_channel)
        idx += 1
        next_channel = channels[idx % channels.length] || 1
      end

      return next_channel
    end
  end
end
