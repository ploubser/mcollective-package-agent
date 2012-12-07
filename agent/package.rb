module MCollective
  module Agent
    class Package<RPC::Agent

      action 'install' do
        begin
          Package.do_pkg_action(request[:package], :install, reply)
        rescue => e
          reply.fail! "Could not install package: %s" % e.to_s
        end
      end

      action 'update' do
        begin
          Package.do_pkg_action(request[:package], :update, reply)
        rescue => e
          reply.fail! "Could not update package: %s" % e.to_s
        end
      end

      action 'uninstall' do
        begin
          Package.do_pkg_action(request[:package], :uninstall, reply)
        rescue => e
          reply.fail! "Could not uninstall package: %s" % e.to_s
        end
      end

      action 'purge' do
        begin
          Package.do_pkg_action(request[:package], :purge, reply)
        rescue => e
          reply.fail! "Could not purge package: %s" % e.to_s
        end
      end

      action 'status' do
        begin
          Package.do_pkg_action(request[:package], :status, reply)
        rescue => e
          reply.fail! "Could not determine package status: %s" % e.to_s
        end
      end

      action 'yum_clean' do
        clean_mode = request[:mode] || @config.pluginconf.fetch('package.yum_clean_mode', 'all')

        begin
          result = package_helper.yum_clean(clean_mode)
          reply[:exitcode] = result[:exitcode]
          reply[:output] = result[:output]
        rescue => e
          reply.fail! e.to_s
        end
      end

      action 'apt_update' do
        begin
          result = package_helper.apt_update
          reply[:exitcode] = result[:exitcode]
          reply[:output] = result[:output]
        rescue => e
          reply.fail! e.to_s
        end
      end

      action 'checkupdates' do
        begin
          do_checkupdates_action('checkupdates')
        rescue => e
          reply.fail! e.to_s
        end
      end

      action 'yum_checkupdates' do
        begin
          do_checkupdates_action('yum_checkupdates')
        rescue => e
          reply.fail! e.to_s
        end
      end

      action 'apt_checkupdates' do
        begin
          do_checkupdates_action('apt_checkupdates')
        rescue => e
          reply.fail! e.to_s
        end
      end

      # Identifies the configured package provider
      # Defaults to puppet
      def self.package_provider
        @config ||= Config.instance
        return @config.pluginconf.fetch('package.provider', 'puppet')
      end

      # Loads both the base class that all providers should inherit from,
      # as well as the actual provider class that implements the install,
      # uninstall, purge, update and status methods.
      def self.load_provider_class(provider)
        provider = "%sPackage" % provider.capitalize
        Log.debug("Loading %s package provider" % provider)

        begin
          PluginManager.loadclass('MCollective::Util::Package::Base')
          PluginManager.loadclass("MCollective::Util::Package::#{provider}")
          Util::Package.const_get(provider)
        rescue => e
          Log.debug("Cannot load package provider class '%s': %s" % [provider, e.to_s])
          raise "Cannot load package provider class '%s': %s" % [provider, e.to_s]
        end
      end

      # Parses the plugin configuration for all configuration options
      # specific to package provider.
      # Configuration options are defined as:
      #
      #   plugin.package.my_provider.x = y
      #
      # which will then be resturned as
      #
      #   {:x => 'y'}
      #
      def self.provider_options(provider)
        @config ||= Config.instance
        provider_options = {}

        @config.pluginconf.each do |k, v|
          if k =~ /package\.#{provider}/
            provider_options[k.split('.').last.to_sym] = v
          end
        end

        provider_options
      end

      # Loads the requires package provider and calls the method that
      # corresponds to the supplied action. The third arugment is an
      # in-out variable used to update the reply values in the case of
      # agents, and the value hash in the case of data plugins.
      def self.do_pkg_action(package, action, reply)
        provider = Package.load_provider_class(Package.package_provider).new(package, Package.provider_options(Package.package_provider))
        result = provider.send(action)

        if action == :status
          result.each do |k,v|
            reply[k] = v
          end
        else
          result[:status].each do |k,v|
            reply[k] = v
          end
        end

        raise result[:msg] if result[:msg]

        reply[:output] = result[:output] if result[:output]
      end

      private
      # Calls the correct helper method corresponding to the supplied
      # action and updates the agents reply values.
      def do_checkupdates_action(action)
        result = package_helper.send(action)
        reply[:exitcode] = result[:exitcode]
        reply[:output] = result[:output]
        reply[:outdated_packages] = result[:outdated_packages]
        reply[:package_manager] = result[:package_manager]
      end

      #Loads and returns the package_helper class
      def package_helper
        PluginManager.loadclass('MCollective::Util::Package::PackageHelpers')
        Util::Package.const_get('PackageHelpers')
      end
    end
  end
end
