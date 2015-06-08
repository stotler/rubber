require 'rubber/cloud/generic'
require 'yaml/store'

module Rubber
  module Cloud
    # YAML file containing a set of servers available for use.
    class YAML < Base
      AVAILABLE = 'available'.freeze
      ACTIVE = 'running'.freeze
      STOPPED = 'stopped'.freeze # not actually used just defined to implement the cloud interface

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
        instances = db = self.class.load_database(database_file)

        if datacenter.length > 0
          instances = db.select(&find_by_datacenter(datacenter))
        end

        instance = instances.find(&find_by_states(AVAILABLE))

        raise StandardError.new("No Servers Available") if instance.nil?

        instance.state = ACTIVE

        self.class.dump_database(db, database_file)

        instance.id
      end

      def describe_instances(instance_id=nil)
        instances = self.class.load_database(database_file).select(&find_by_states(ACTIVE, STOPPED))
        if instance_id
          instances = instances.select(&find_by_uuid(instance_id))
          if instances.empty?
            raise StandardError.new("No Server Matches ID")
          end

          if instances.count > 1
            raise StandardError.new("Found more than 1 server with given ID")
          end
        end

        instances.collect do |instance|
          instance.provider = self.class.name.split('::').last
          instance.platform = Rubber::Platforms::LINUX

          # convert to hash to match interface
          instance.to_h
        end
      end

      def destroy_instance(instance_id)
        db = self.class.load_database(database_file)
        instance = db.find(&find_by_uuid(instance_id))
        return if instance.nil?

        # Mark the instance as available again.
        instance.state = AVAILABLE

        self.class.dump_database(db, database_file)
      end

      class Instance < Struct.new(:id, :state, :datacenter, :external_ip, :internal_ip, :platform, :provider)
        def initialize(id, state, datacenter, external_ip, internal_ip, platform, prodiver)
          super(id, state || AVAILABLE, datacenter, external_ip, internal_ip, platform, provider)
        end
      end

      #private

      def self.dump_database(database, database_file)
        File.open(database_file + ".tmp", "w") do |f|
          f.write(::YAML.dump(database))
        end

        if File.exists?(database_file)
          FileUtils.mv(database_file, database_file + ".bak")
        end

        FileUtils.mv(database_file + ".tmp", database_file)
      end

      def self.load_database(file)
        @database = (::YAML.load(File.open(file)) || [])
      # create an empty db if the file doesn't exist.
      rescue Errno::ENOENT => e
        @database = []
      end

      def find_by_states(*states)
        lambda { |i| states.include?(i.state) }
      end

      def find_by_datacenter(datacenter)
        lambda { |i| i.datacenter == datacenter }
      end

      # @param [String] id
      def find_by_uuid(id)
        lambda { |i| i.id == id }
      end
    end
  end
end
