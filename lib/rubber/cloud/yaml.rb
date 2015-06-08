require 'rubber/cloud/generic'
require 'yaml/store'

module Rubber
  module Cloud
    # YAML file containing a set of servers available for use.
    class YAML < Base
      PROVIDER = 'YAML'.freeze
      AVAILABLE = 'available'.freeze
      ACTIVE = 'running'.freeze
      STOPPED = 'stopped'.freeze

      def database_file
        ENV["YAML_DATABASE"]
      end

      def active_state
        ACTIVE
      end

      def stopped_state
        STOPPED
      end

      def create_instance(instance_alias, image_name, image_type, security_groups, availability_zone, datacenter)
        instance = database.select(&find_by_datacenter).find(&find_by_state(AVAILABLE))
        return nil if instance.nil?

        instance.state = ACTIVE

        dump_database

        instance.id
      end

      def describe_instances(instance_id=nil)
        # sanity guard in case someone defined a server without an id.
        return nil if instance_id.nil?

        instance = database.find(&find_by_uuid(instance_id)).dup

        instance.provider = PROVIDER
        instance.platform = Rubber::Platforms::LINUX

        instance.to_h
      end

      def destroy_instance(instance_id)
        instance = database.find(&find_by_uuid(instance_id))
        return if instance.nil?

        # Mark the instance as available again.
        instance.state = AVAILABLE

        dump_database
      end

      private

      def dump_database
        File.open(database_file + ".tmp") do |f|
          f.write(YAML.dump(database))
        end

        FileUtils.mv(database_file, database_file + ".bak")
        FileUtils.mv(database_file + ".tmp", database_file)
      end

      def database
        @database ||= (YAML.load(File.open(database_file)) || [])
      # create an empty db if the file doesn't exist.
      rescue Errno::ENOENT => e
        @database = []
      end

      def find_by_state(state)
        lambda { |i| i.state == state }
      end

      def find_by_datacenter(datacenter)
        lambda { |i| i.datacenter == datacenter }
      end

      # @param [String] id
      def find_by_uuid(id)
        lambda { |i| i.id == id }
      end

      class Instance < Struct.new(:id, :state, :datacenter, :external_ip, :internal_ip, :platform, :provider); end
    end
  end
end
