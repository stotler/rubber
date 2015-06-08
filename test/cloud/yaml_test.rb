require File.expand_path(File.join(__FILE__, '../..', 'test_helper'))
require 'rubber/cloud/yaml'

class YAMLTest < Test::Unit::TestCase
  context 'yaml' do
    setup do
      ENV["YAML_DATABASE"] = "/tmp/#{SecureRandom.uuid}"

      env = Rubber::Configuration::Environment::BoundEnv.new({}, nil, nil, nil)
      @cloud = Rubber::Cloud::YAML.new(env, nil)
    end

    teardown do
      FileUtils.rm_f(ENV.delete("YAML_DATABASE"))
    end

    should 'create instance' do
      db = [
        Rubber::Cloud::YAML::Instance.new(SecureRandom.uuid, Rubber::Cloud::YAML::AVAILABLE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
      ]

      Rubber::Cloud::YAML.persist_database(db, ENV["YAML_DATABASE"])

      assert_equal db.first.id, @cloud.create_instance('', '', '', '', '', '')
    end

    context 'describe_instances' do
      should 'be able to describe all instances if no instance id is provided' do
        db = [
          Rubber::Cloud::YAML::Instance.new(SecureRandom.uuid, Rubber::Cloud::YAML::ACTIVE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
          Rubber::Cloud::YAML::Instance.new(SecureRandom.uuid, Rubber::Cloud::YAML::STOPPED, 'dc1', '127.0.0.2', '10.0.0.2', nil, nil),
          Rubber::Cloud::YAML::Instance.new(SecureRandom.uuid, Rubber::Cloud::YAML::AVAILABLE, 'dc1', '127.0.0.3', '10.0.0.3', nil, nil),
        ]

        # Load DB.
        Rubber::Cloud::YAML.persist_database(db, ENV["YAML_DATABASE"])

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
          Rubber::Cloud::YAML::Instance.new(SecureRandom.uuid, Rubber::Cloud::YAML::AVAILABLE, 'dc0', '127.0.0.1', '10.0.0.1', nil, nil),
        ]

        Rubber::Cloud::YAML.persist_database(db, ENV["YAML_DATABASE"])

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
  end
end
