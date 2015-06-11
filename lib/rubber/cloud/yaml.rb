require 'rubber/cloud/generic'
require 'yaml/store'

module Rubber
  module Cloud
    # YAML file containing a set of servers available for use.
    # Implements the rubber's provisioner interface
    # create_instance, describe_instances, destroy_instance
    class Yaml < Base
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

      # Marks an instance as ACTIVE within the database file.
      # Arguments beginning with _ are ignored by this method.
      # @param [String] _instance_alias  (Ignored) - the alias of the instance being created.
      # @param [String] _image_name (Ignored) - the name of the base machine image to use.
      # @param [String] _image_type (Ignored) - the type of machine to create (i.e. hardware specs)
      # @param [Array]  _security_groups (Ignored) - the security groups to apply to the machine.
      # @param [String] _availability_zone (Ignored) - the availability zone to create the server within.
      # @param [String] datacenter - the data center to create the server within.
      # @return [String] id of the created machine.
      def create_instance(_instance_alias, _image_name, _image_type, _security_groups, _availability_zone, datacenter)
        instances = db = self.class.load_database(database_file)

        if datacenter && datacenter.length > 0
          instances = db.select(&find_by_datacenter(datacenter))
        end

        instance = instances.find(&find_by_states(AVAILABLE))

        raise StandardError.new("No Servers Available") if instance.nil?

        instance.state = ACTIVE

        self.class.persist_database(db, database_file)

        instance.id
      end

      # Returns information about the currently provisioned servers.
      # @param [String] instance_id - describe the specific instance for the provided id.
      # @return [Hash]
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

      # Marks the machine with the given id as available. if the instance does not exist,
      # just return.
      def destroy_instance(instance_id)
        db = self.class.load_database(database_file)
        instance = db.select(&find_by_states(ACTIVE, STOPPED)).find(&find_by_uuid(instance_id))
        raise StandardError.new("No Server Matches ID") if instance.nil?

        # Mark the instance as available again.
        instance.state = AVAILABLE

        self.class.persist_database(db, database_file)
      end

      class Instance < Struct.new(:id, :state, :datacenter, :external_ip, :internal_ip, :platform, :provider)
        def initialize(id, state, datacenter, external_ip, internal_ip, platform, provider)
          super(id, state || AVAILABLE, datacenter, external_ip, internal_ip, platform, provider)
        end
      end

      def self.persist_database(database, database_file)
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
