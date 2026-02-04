# frozen_string_literal: true

require_relative 'public_testnet'

module HestiaChain
  module Backend
    # PublicMainnet backend submits anchors to a public blockchain mainnet.
    #
    # This backend is designed for:
    # - Stage 3 production deployment
    # - Permanent, immutable anchor storage
    # - Maximum security and decentralization
    #
    # Supported mainnets:
    # - Base (recommended - low gas costs)
    # - Ethereum (highest security, higher costs)
    #
    # IMPORTANT: This backend uses real money (ETH) for gas fees.
    # Always test thoroughly on testnet first.
    #
    # @example Configuration
    #   config:
    #     backend: public_mainnet
    #     batching:
    #       enabled: true
    #       max_batch_size: 100
    #       interval_seconds: 3600
    #     public_mainnet:
    #       chain: base
    #       rpc_url: https://mainnet.base.org
    #       contract_address: 0x...
    #       private_key_env: HESTIA_PRIVATE_KEY
    #
    class PublicMainnet < PublicTestnet
      SUPPORTED_CHAINS = %w[base ethereum].freeze

      def initialize(config)
        # Use parent initialization but with mainnet-specific validation
        @config = config
        @chain = config.backend_config['chain'] || 'base'
        @rpc_url = config.backend_config['rpc_url']
        @contract_address = config.backend_config['contract_address']
        @private_key_env = config.backend_config['private_key_env'] || 'HESTIA_PRIVATE_KEY'

        validate_mainnet_config!
        initialize_client

        # Warn about mainnet usage
        warn "[HestiaChain::PublicMainnet] WARNING: Using MAINNET. Real ETH will be spent on gas fees."
      end

      # Get backend type
      #
      # @return [Symbol] :public_mainnet
      #
      def backend_type
        :public_mainnet
      end

      # Get statistics with mainnet-specific info
      #
      # @return [Hash] Backend statistics
      #
      def stats
        base_stats = super
        
        # Add balance info for mainnet
        balance = begin
          ensure_eth_gem!
          wei = @client.get_balance(@key.address)
          eth = wei.to_f / 1e18
          "#{eth.round(6)} ETH"
        rescue StandardError
          'unknown'
        end

        base_stats.merge(
          account_balance: balance,
          warning: 'MAINNET - Real ETH is being used'
        )
      end

      private

      def validate_mainnet_config!
        raise HestiaChain::ConfigurationError, 'rpc_url is required' unless @rpc_url
        raise HestiaChain::ConfigurationError, 'contract_address is required' unless @contract_address
        return if SUPPORTED_CHAINS.include?(@chain)

        raise HestiaChain::ConfigurationError,
              "Unsupported mainnet chain: #{@chain}. Supported: #{SUPPORTED_CHAINS.join(', ')}"
      end
    end
  end
end
