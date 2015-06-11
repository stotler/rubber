require File.expand_path(File.join(__FILE__, '../..', 'test_helper'))
require 'rubber/cloud/yaml'

class YAMLTest < Test::Unit::TestCase
  context 'yaml' do
    setup do
      ENV["YAML_DATABASE"] = "/tmp/#{SecureRandom.uuid}"

      env = Rubber::Configuration::Environment::BoundEnv.new({}, nil, nil, nil)
      @cloud = Rubber::Cloud::Yaml.new(env, nil)
    end

    teardown do
      FileUtils.rm_f(ENV.delete("YAML_DATABASE"))
    end

    context 'create_instance' do
      should 'create instance' do
        db = [
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
        ]

        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal db.first.id, @cloud.create_instance('', '', '', '', '', '')
        instance = @cloud.describe_instances(db.first.id).first

        # ensure creating the instance populated the two missing fields.
        assert_equal instance[:provider], 'Yaml'
        assert_equal instance[:platform], Rubber::Platforms::LINUX
      end

      should 'handle nil datacenter' do
        db = [
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, nil, '127.0.0.1', '10.0.0.1', nil, nil),
        ]

        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal db.first.id, @cloud.create_instance('', '', '', '', '', nil)
        instance = @cloud.describe_instances(db.first.id).first

        # ensure creating the instance populated the two missing fields.
        assert_equal instance[:provider], 'Yaml'
        assert_equal instance[:platform], Rubber::Platforms::LINUX
      end
    end

    context 'describe_instances' do
      should 'be able to describe all instances if no instance id is provided' do
        db = [
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::ACTIVE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::STOPPED, 'dc1', '127.0.0.2', '10.0.0.2', nil, nil),
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc1', '127.0.0.3', '10.0.0.3', nil, nil),
        ]

        # Load DB.
        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        instances = @cloud.describe_instances
        assert_equal 2, instances.count
        refute instances.collect{|hash| hash[:id]}.include?(db.last.id)
      end

      should 'return empty array if no instances' do
        assert @cloud.describe_instances.empty?
      end

      # Current behaviour not sure if this is what we want long term.
      should 'error if the provided instance id does not exist' do
        exception = assert_raises(StandardError)do
          assert @cloud.describe_instances("0000")
        end

        assert "Worker 0000 doesn't exist", exception.message
      end

      should 'return just information about the requested instance' do
        db = [
          Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
        ]

        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal 0, @cloud.describe_instances.count

        # create an instance
        instance_id = @cloud.create_instance('', '', '', '', '', '')

        instances = @cloud.describe_instances(instance_id)

        assert_equal 1, instances.count
        [:id, :datacenter, :external_ip, :internal_ip].each do |attr|
          assert_equal db.first.send(attr), instances.first[attr]
        end
      end
    end

    context 'destroy instance' do
      should 'update the database for a running server from running to available' do
        active = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::ACTIVE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil)
        stopped = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::STOPPED, 'dc1', '127.0.0.2', '10.0.0.2', nil, nil)
        available = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc1', '127.0.0.3', '10.0.0.3', nil, nil)

        db = [active, stopped, available]

        # Load DB.
        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal 2, @cloud.describe_instances.count

        @cloud.destroy_instance(active.id)

        assert_equal 1, @cloud.describe_instances.count
      end

      should 'update the database for a running server from stopped to available' do
        active = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::ACTIVE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil)
        stopped = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::STOPPED, 'dc1', '127.0.0.2', '10.0.0.2', nil, nil)
        available = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc1', '127.0.0.3', '10.0.0.3', nil, nil)

        db = [active, stopped, available]

        # Load DB.
        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal 2, @cloud.describe_instances.count

        @cloud.destroy_instance(stopped.id)

        assert_equal 1, @cloud.describe_instances.count
      end

      should 'error if destroy is called on an available server' do
        active = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::ACTIVE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil)
        stopped = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::STOPPED, 'dc1', '127.0.0.2', '10.0.0.2', nil, nil)
        available = Rubber::Cloud::Yaml::Instance.new(SecureRandom.uuid, Rubber::Cloud::Yaml::AVAILABLE, 'dc1', '127.0.0.3', '10.0.0.3', nil, nil)

        db = [active, stopped, available]

        # Load DB.
        Rubber::Cloud::Yaml.persist_database(db, ENV["YAML_DATABASE"])

        assert_equal 2, @cloud.describe_instances.count

        exception = assert_raises(StandardError)do
          @cloud.destroy_instance(available.id)
        end

        assert "No Server Matches ID", exception.message

        assert_equal 2, @cloud.describe_instances.count
      end
    end
  end
end
