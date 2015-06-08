require File.expand_path(File.join(__FILE__, '../..', 'test_helper'))
require 'rubber/cloud/yaml'

# NOTE: Must re-record one at a time for any test that invokes create_instance.
# This is true until we allow povisioning arbitrarily, or if you expect the instances list to
# be empty.
class YAMLTest < Test::Unit::TestCase
  context 'yaml' do
    setup do
      @dbfile = "/tmp/#{SecureRandom.uuid}"
      # env = {
      #   'database' => @dbfile,
      # }

      env = Rubber::Configuration::Environment::BoundEnv.new(env, nil, nil, nil)
      @cloud = Rubber::Cloud::YAML.new(env, nil)
    end

    teardown do
      FileUtils.rm(@dbfile)
    end

    should 'create instance' do
      assert @cloud.create_instance('', '', '', '', '', '')
    end

    context 'describe_instances' do
      should 'be able to describe all instances if no instance id is provided' do
        # create an instance
        assert @cloud.create_instance('', '', '', '', '', '')

        instances = @cloud.describe_instances
        assert_equal 1, instances.count
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
        # create an instance
        instance_id = @cloud.create_instance('', '', '', '', '', '')

        instances = @cloud.describe_instances

        assert_equal Integer(instance_id, 10), instances.first[:id]
      end
    end
  end
end
