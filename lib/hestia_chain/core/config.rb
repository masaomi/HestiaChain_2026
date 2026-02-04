# frozen_string_literal: true

require 'yaml'
require 'erb'

module HestiaChain
  module Core
    # Config manages HestiaChain configuration.
    #
    # Configuration can be loaded from:
    # - YAML file (config/hestia_chain.yml)
    # - Hash passed directly
    # - Environment variables
    #
    # @example Load from file
    #   config = HestiaChain::Core::Config.load
    #
    # @example Load with custom path
    #   config = HestiaChain::Core::Config.load(path: '/path/to/config.yml')
    #
    # @example Create from hash
    #   config = HestiaChain::Core::Config.new(backend: 'in_memory')
    #
    class Config
      DEFAULT_CONFIG = {
        'enabled' => true,
        'backend' => 'in_memory',
        'batching' => {
          'enabled' => false,
          'interval_seconds' => 3600,
          'max_batch_size' => 100
        },
        'in_memory' => {},
        'private' => {
          'storage_path' => 'storage/hestia_anchors.json',
          'max_anchors' => 100_000
        },
        'public_testnet' => {
          'chain' => 'base_sepolia',
          'rpc_url' => nil,
          'contract_address' => nil,
          'private_key_env' => 'HESTIA_PRIVATE_KEY'
        },
        'public_mainnet' => {
          'chain' => 'base',
          'rpc_url' => nil,
          'contract_address' => nil,
          'private_key_env' => 'HESTIA_PRIVATE_KEY'
        }
      }.freeze

      DEFAULT_PATHS = [
        'config/hestia_chain.yml',
        'hestia_chain.yml',
        '~/.hestia_chain.yml'
      ].freeze

      attr_reader :config

      # Create a new Config instance
      #
      # @param config [Hash] Configuration hash
      #
      def initialize(config = {})
        @config = deep_merge(DEFAULT_CONFIG, stringify_keys(config))
      end

      # Load configuration from file
      #
      # @param path [String, nil] Path to config file (auto-detected if nil)
      # @param environment [String, nil] Environment to use (defaults to HESTIA_ENV or 'development')
      # @return [Config] Config instance
      #
      def self.load(path: nil, environment: nil)
        env = environment || ENV['HESTIA_ENV'] || ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development'
        config_path = path || find_config_file

        if config_path && File.exist?(config_path)
          yaml_content = ERB.new(File.read(config_path)).result
          full_config = YAML.safe_load(yaml_content, permitted_classes: [Symbol]) || {}
          env_config = full_config[env] || full_config['default'] || {}
          new(env_config)
        else
          new({})
        end
      end

      # Find configuration file from default paths
      #
      # @return [String, nil] Path to config file or nil if not found
      #
      def self.find_config_file
        DEFAULT_PATHS.each do |path|
          expanded = File.expand_path(path)
          return expanded if File.exist?(expanded)
        end
        nil
      end

      # Check if HestiaChain is enabled
      #
      # @return [Boolean] True if enabled
      #
      def enabled?
        @config['enabled'] == true
      end

      # Get the backend type
      #
      # @return [String] Backend type (in_memory, private, public_testnet, public_mainnet)
      #
      def backend
        @config['backend']
      end

      # Check if batching is enabled
      #
      # @return [Boolean] True if batching is enabled
      #
      def batching_enabled?
        @config.dig('batching', 'enabled') == true
      end

      # Get batching interval in seconds
      #
      # @return [Integer] Batch interval
      #
      def batch_interval
        @config.dig('batching', 'interval_seconds') || 3600
      end

      # Get maximum batch size
      #
      # @return [Integer] Maximum batch size
      #
      def max_batch_size
        @config.dig('batching', 'max_batch_size') || 100
      end

      # Get backend-specific configuration
      #
      # @param backend_name [String, nil] Backend name (defaults to current backend)
      # @return [Hash] Backend configuration
      #
      def backend_config(backend_name = nil)
        name = backend_name || backend
        @config[name] || {}
      end

      # Get a configuration value by key path
      #
      # @param keys [Array<String>] Key path
      # @return [Object, nil] Configuration value
      #
      def dig(*keys)
        @config.dig(*keys.map(&:to_s))
      end

      # Access configuration like a hash
      #
      # @param key [String, Symbol] Configuration key
      # @return [Object, nil] Configuration value
      #
      def [](key)
        @config[key.to_s]
      end

      # Convert to hash
      #
      # @return [Hash] Configuration hash (sensitive values masked)
      #
      def to_h
        mask_sensitive(@config.dup)
      end

      # String representation
      #
      # @return [String] Configuration summary
      #
      def inspect
        "#<HestiaChain::Config backend=#{backend} enabled=#{enabled?} batching=#{batching_enabled?}>"
      end

      private

      # Deep merge two hashes
      #
      # @param base [Hash] Base hash
      # @param override [Hash] Override hash
      # @return [Hash] Merged hash
      #
      def deep_merge(base, override)
        base.merge(override) do |_key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      # Convert all keys to strings
      #
      # @param hash [Hash] Hash to convert
      # @return [Hash] Hash with string keys
      #
      def stringify_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          result[key.to_s] = value.is_a?(Hash) ? stringify_keys(value) : value
        end
      end

      # Mask sensitive values in config
      #
      # @param hash [Hash] Configuration hash
      # @return [Hash] Hash with sensitive values masked
      #
      def mask_sensitive(hash)
        sensitive_keys = %w[private_key secret_key api_key password]

        hash.each_with_object({}) do |(key, value), result|
          result[key] = if sensitive_keys.any? { |k| key.to_s.include?(k) }
                          '[MASKED]'
                        elsif value.is_a?(Hash)
                          mask_sensitive(value)
                        else
                          value
                        end
        end
      end
    end
  end
end
