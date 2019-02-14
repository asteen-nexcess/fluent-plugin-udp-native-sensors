#
# Copyright (c) 2017 Juniper Networks, Inc. All rights reserved.
#

require 'juniper_telemetry_udp_lib.rb'
require 'protobuf'
require 'telemetry_top.pb.rb'
require 'port.pb.rb'
require 'lsp_stats.pb.rb'
require 'logical_port.pb.rb'
require 'firewall.pb.rb'
require 'cpu_memory_utilization.pb.rb'
require 'qmon.pb.rb'
require 'cmerror.pb.rb'
require 'cmerror_data.pb.rb'
require 'fabric.pb.rb'
require 'inline_jflow.pb.rb'
require 'lsp_mon.pb.rb'
require 'npu_utilization.pb.rb'
require 'npu_memory_utilization.pb.rb'
require 'port_exp.pb.rb'
require 'packet_stats.pb.rb'
require 'optics.pb.rb'
require 'port.pb.rb'
require 'socket'
require 'json'

module Fluent
  module Plugin
    class JuniperUdpNativeParser < Parser

      Fluent:: Plugin.register_parser("juniper_udp_native", self)

      config_param :output_format, :string, :default => 'structured'

      # This method is called after config_params have read configuration parameters
      def configure(conf)
        super

        ## Check if "output_format" has a valid value
        unless  @output_format.to_s == "structured" ||
                @output_format.to_s == "flat" ||
                @output_format.to_s == "statsd"

          raise ConfigError, "output_format value '#{@output_format}' is not valid. Must be : structured, flat or statsd"
        end
      end

      def parse(text)

        host = Socket.gethostname

        ## Decode GBP packet
        jti_msg =  TelemetryStream.decode(text)

        resource = ""

        ## Extract device name & Timestamp
        device_name = jti_msg.system_id
        yield_time = epoc_to_sec(jti_msg.timestamp)
        gpb_time = epoc_to_ms(jti_msg.timestamp)
        measurement_prefix = "enterprise.juniperNetworks"

        ## Extract sensor
        begin
          jnpr_sensor = jti_msg.enterprise.juniperNetworks
          datas_sensors = JSON.parse(jnpr_sensor.to_json)
        rescue => e
          return
        end

        ## Go over each Sensor
        final_data = Array.new
        datas_sensors.each do |sensor, s_data|
            if s_data.is_a? Hash
                final_data = parse_hash(s_data, jnpr_sensor)
                if final_data[0].is_a? Hash
                    final_data = final_data
                else
                    final_data = final_data[0]
                end
            end
        end

        
        for data in final_data
            data['device'] = device_name
            data['host'] = host
            data['sensor_name'] = datas_sensors.keys[0]
            data['time'] = gpb_time
        end

        for data in final_data
            yield yield_time, data
        end


      end
    end
  end
end

