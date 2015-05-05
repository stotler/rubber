require 'rubber/cloud/generic'

module Rubber
  module Cloud
    class Vagrant < Generic

      def active_state
        'running'
      end

      def stopped_state
        'saved'
      end

      def create_instance(instance_alias, image_name, image_type, security_groups, availability_zone, region)
        unless ENV.has_key?('RUN_FROM_VAGRANT')
          run_vagrant_command('up', instance_alias)
        end

        instance = setup_vagrant_instance(instance_alias, active_state)
        Generic.add_instance(instance)

        instance_alias
      end

      def describe_instances(instance_id=nil)
        output = run_vagrant_command('status', instance_id, '', true)
        output =~ /#{instance_id}\s+(\w+)/m
        state = $1

        if Generic.instances
          Generic.instances.each do |instance|
            if instance[:id] == instance_id
              instance[:state] = state
              instance[:provider] = 'vagrant'
            end
          end

          Generic.instances
        else
          # Get info from currently running instance (or prompt user)
          instance = setup_vagrant_instance(instance_id, state)
          [instance]
        end
      end

      def destroy_instance(instance_id)
        # If it's being run from vagrant, then 'vagrant destroy' must have been called already, so no need for us to do it.
        unless ENV.has_key?('RUN_FROM_VAGRANT')
          run_vagrant_command('destroy', instance_id, '--force')
        end
      end

      def stop_instance(instance, force=false)
        run_vagrant_command('suspend', instance.instance_id)
      end

      def start_instance(instance)
       run_vagrant_command('resume', instance.instance_id)
      end

      private

      def run_vagrant_command(subcmd, instance_or_id = nil, args = "", return_result = false)
        # Parse instance_or_id
        instance = instance_or_id.kind_of?(String) ? Rubber.instances[instance_or_id] : instance_or_id
        id = instance ? instance.instance_id : instance_or_id
        vagrant_cwd = get_vagrant_cwd(instance)

        # Build command 'VAGRANT_CWD=<cwd> vagrant <subcmd> <id> <args>'
        cmd = ''
        cmd += "VAGRANT_CWD=#{vagrant_cwd} " if vagrant_cwd
        cmd += 'vagrant ' + subcmd
        cmd += ' ' + id if id
        cmd += ' ' + args unless args.empty?

        capistrano.logger.info("Running '#{cmd}'")

        if return_result
          `#{cmd}`
        else
          system(cmd)
        end
      end

      def get_vagrant_cwd(instance)
        return nil unless instance && instance.respond_to?(:provider_options) && instance.provider_options
        cwd = instance.provider_options[:vagrant_cwd]
        return nil if cwd && cwd.empty?
        cwd
      end

      def setup_vagrant_instance(instance_alias, state)
        instance = {}
        instance[:id] = instance_alias
        instance[:state] = state
        instance[:provider] = 'vagrant'
        instance[:platform] = Rubber::Platforms::LINUX

        if ENV.has_key?('VAGRANT_CWD')
          instance[:provider_options] ||= {}
          instance[:provider_options][:vagrant_cwd] = ENV['VAGRANT_CWD']
        end

        # IP addresses
        ip = instance_external_ip(instance_alias)
        if ! ip.empty?
          capistrano.logger.info("Using #{ip} for external and internal IP address")
          instance[:external_ip] = instance[:internal_ip] = ip
        else
          instance[:external_ip] = capistrano.rubber.get_env('EXTERNAL_IP', "External IP address for host '#{instance_alias}'", true)
          instance[:internal_ip] = capistrano.rubber.get_env('INTERNAL_IP', "Internal IP address for host '#{instance_alias}'", true, instance[:external_ip])
        end

        instance
      end

      def instance_external_ip(instance_id)
        return nil if instance_id.empty?
        capistrano.logger.info("Getting Vagrant instance external IP")
        ips = run_vagrant_command('ssh', instance_id, "-c 'ifconfig | awk \"/inet addr/{print substr(\\$2,6)}\"' 2> /dev/null", true)
        ips = ips.split(/\r?\n/) # split on CRLF or LF
        if ips.empty? 
          capistrano.logger.error("Unable to retrieve IP addresses from Vagrant instance")
          nil
        else
          original_ips = ips.dup
          ips.delete_if { |x| /^127\./.match(x) }  # Delete the loopback address
          ips.delete_if { |x| /^192\.168\.12/.match(x) }  # Delete the internally assigned Vagrant address: 192.168.12X.X
          if ips.empty?
            capistrano.logger.error("Vagrant instance doesn't appear to have an external IP address. IPs found are: #{original_ips.join(', ')}")
            nil
          else
            capistrano.logger.info("The vagrant instance 'external' IP is #{ips.first}")
            ips.first
          end
        end
      end

    end
  end
end
