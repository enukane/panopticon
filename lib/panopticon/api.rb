module Panopticon
  require "sinatra/base"
  require "json"

  require "panopticon/wlan_control"

  class APIServer < Sinatra::Base
    DEFAULT_PORT=8080

    set :port, DEFAULT_PORT
    set :public_folder, File.dirname(__FILE__) + "/../../extra/public"
    enable :logging

    def self.run! arg={}
      @arg = arg

      @port = arg[:port] || DEFAULT_PORT
      set :port, @port

      @@wlan_control = Panopticon::WlanControl.new(arg)
      super
    end

    get "/" do
      redirect to ("/index.html")
    end

    get "/api/v1/status" do
      JSON.dump(@@wlan_control.get_status)
    end

    post "/api/v1/start" do
      begin
        data =  request.body.read
        json = JSON.parse(data)

        @@wlan_control.start_capture(json)
        status 200
        "success"
      rescue => e
        $log.err("/start failed => #{e}")
        status 500
        "failed (#{e})"
      end
    end

    post "/api/v1/stop" do
      begin
        @@wlan_control.stop_capture
        status 200
        "success"
      rescue => e
        $log.err("/start failed => #{e}")
        status 500
        "failed (#{e})"
      end
    end
  end
end
