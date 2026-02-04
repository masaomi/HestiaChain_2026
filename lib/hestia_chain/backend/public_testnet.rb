# frozen_string_literal: true

require_relative 'base'

module HestiaChain
  module Backend
    # PublicTestnet backend submits anchors to a public blockchain testnet.
    #
    # This backend is designed for:
    # - Stage 2 deployment (testing on real blockchain)
    # - Validating smart contract integration
    # - Testing gas costs and batching strategies
    #
    # Supported testnets:
    # - Base Sepolia (recommended)
    # - Ethereum Sepolia
    #
    # @example Configuration
    #   config:
    #     backend: public_testnet
    #     public_testnet:
    #       chain: base_sepolia
    #       rpc_url: https://sepolia.base.org
    #       contract_address: 0x...
    #       private_key_env: HESTIA_TESTNET_PRIVATE_KEY
    #
    # @note Requires the 'eth' gem: gem 'eth', '~> 0.5'
    #
    class PublicTestnet < Base
      SUPPORTED_CHAINS = %w[base_sepolia sepolia].freeze
      DEFAULT_GAS_LIMIT = 100_000
      BATCH_GAS_LIMIT = 500_000

      def initialize(config)
        super
        @chain = config.backend_config['chain'] || 'base_sepolia'
        @rpc_url = config.backend_config['rpc_url']
        @contract_address = config.backend_config['contract_address']
        @private_key_env = config.backend_config['private_key_env'] || 'HESTIA_TESTNET_PRIVATE_KEY'

        validate_config!
        initialize_client
      end

      # Submit an anchor to the testnet
      #
      # @param anchor [HestiaChain::Core::Anchor] Anchor to submit
      # @return [Hash] Result with transaction details
      #
      def submit_anchor(anchor)
        validate_anchor!(anchor)
        ensure_eth_gem!

        hash = normalize_hash(anchor.anchor_hash)
        anchor_type = anchor.anchor_type

        # Check if already exists (save gas)
        if anchor_exists_on_chain?(hash)
          return {
            status: 'exists',
            anchor_hash: hash,
            message: 'Anchor already exists on chain'
          }
        end

        # Submit to blockchain
        tx_hash = call_contract_record(hash, anchor_type)

        {
          status: 'submitted',
          anchor_hash: hash,
          tx_hash: tx_hash,
          chain: @chain,
          backend: 'public_testnet'
        }
      rescue StandardError => e
        {
          status: 'error',
          anchor_hash: hash,
          error: e.message,
          chain: @chain
        }
      end

      # Submit multiple anchors in a batch
      #
      # @param anchors [Array<HestiaChain::Core::Anchor>] Anchors to submit
      # @return [Hash] Result with transaction details
      #
      def submit_anchors(anchors)
        ensure_eth_gem!

        hashes = anchors.map { |a| normalize_hash(a.anchor_hash) }
        types = anchors.map(&:anchor_type)

        # Filter out existing anchors
        new_hashes = []
        new_types = []
        hashes.zip(types).each do |hash, type|
          unless anchor_exists_on_chain?(hash)
            new_hashes << hash
            new_types << type
          end
        end

        if new_hashes.empty?
          return {
            status: 'all_exist',
            count: 0,
            message: 'All anchors already exist on chain'
          }
        end

        # Submit batch
        tx_hash = call_contract_batch_record(new_hashes, new_types)

        {
          status: 'submitted',
          count: new_hashes.size,
          tx_hash: tx_hash,
          anchor_hashes: new_hashes,
          chain: @chain,
          backend: 'public_testnet'
        }
      rescue StandardError => e
        {
          status: 'error',
          error: e.message,
          chain: @chain
        }
      end

      # Verify an anchor on the blockchain
      #
      # @param anchor_hash [String] Anchor hash to verify
      # @return [Hash] Verification result from blockchain
      #
      def verify_anchor(anchor_hash)
        ensure_eth_gem!

        hash = normalize_hash(anchor_hash)
        result = call_contract_verify(hash)

        if result[:exists]
          {
            exists: true,
            anchor_hash: hash,
            anchor_type: result[:anchor_type],
            timestamp: result[:timestamp],
            recorder: result[:recorder],
            chain: @chain
          }
        else
          {
            exists: false,
            anchor_hash: hash,
            chain: @chain
          }
        end
      rescue StandardError => e
        {
          exists: false,
          anchor_hash: hash,
          error: e.message,
          chain: @chain
        }
      end

      # Get anchor from blockchain
      #
      # @param anchor_hash [String] Anchor hash
      # @return [Hash, nil] Anchor data or nil
      #
      def get_anchor(anchor_hash)
        result = verify_anchor(anchor_hash)
        return nil unless result[:exists]

        result
      end

      # List anchors (limited functionality - uses events)
      #
      # @param limit [Integer] Maximum number of anchors
      # @param anchor_type [String, nil] Filter by type
      # @param since [String, nil] Not supported (ignored)
      # @return [Array<Hash>] Recent anchors from events
      #
      def list_anchors(limit: 100, anchor_type: nil, since: nil)
        # Note: This requires indexing events, which is complex
        # For full functionality, use an off-chain indexer
        warn "[HestiaChain::PublicTestnet] list_anchors is limited. Consider using an indexer."
        []
      end

      # Get backend type
      #
      # @return [Symbol] :public_testnet
      #
      def backend_type
        :public_testnet
      end

      # Check if backend is ready
      #
      # @return [Boolean] True if configured and connected
      #
      def ready?
        return false unless @rpc_url && @contract_address

        # Test connection
        begin
          ensure_eth_gem!
          @client.chain_id
          true
        rescue StandardError
          false
        end
      end

      # Get statistics
      #
      # @return [Hash] Backend statistics
      #
      def stats
        total = begin
          call_contract_total_anchors
        rescue StandardError
          'unknown'
        end

        super.merge(
          chain: @chain,
          rpc_url: mask_url(@rpc_url),
          contract_address: @contract_address,
          total_anchors_on_chain: total
        )
      end

      private

      def validate_config!
        raise HestiaChain::ConfigurationError, 'rpc_url is required' unless @rpc_url
        raise HestiaChain::ConfigurationError, 'contract_address is required' unless @contract_address
        return if SUPPORTED_CHAINS.include?(@chain)

        raise HestiaChain::ConfigurationError, "Unsupported chain: #{@chain}"
      end

      def initialize_client
        # Lazy initialization - only when actually used
        @client = nil
        @key = nil
        @contract = nil
      end

      def ensure_eth_gem!
        require 'eth'
        initialize_eth_client unless @client
      rescue LoadError
        raise HestiaChain::BackendError,
              "The 'eth' gem is required for public blockchain backends. " \
              "Add gem 'eth', '~> 0.5' to your Gemfile."
      end

      def initialize_eth_client
        private_key = ENV[@private_key_env]
        raise HestiaChain::ConfigurationError, "#{@private_key_env} environment variable not set" unless private_key

        @key = Eth::Key.new(priv: private_key)
        @client = Eth::Client.create(@rpc_url)

        # Load contract ABI
        @contract = Eth::Contract.from_abi(
          abi: contract_abi,
          address: @contract_address,
          name: 'HestiaAnchor'
        )
      end

      def contract_abi
        # Minimal ABI for HestiaAnchor contract
        [
          {
            'inputs' => [
              { 'name' => 'anchorHash', 'type' => 'bytes32' },
              { 'name' => 'anchorType', 'type' => 'string' }
            ],
            'name' => 'recordAnchor',
            'outputs' => [{ 'name' => 'success', 'type' => 'bool' }],
            'stateMutability' => 'nonpayable',
            'type' => 'function'
          },
          {
            'inputs' => [
              { 'name' => 'anchorHashes', 'type' => 'bytes32[]' },
              { 'name' => 'types', 'type' => 'string[]' }
            ],
            'name' => 'recordAnchors',
            'outputs' => [{ 'name' => 'recorded', 'type' => 'uint256' }],
            'stateMutability' => 'nonpayable',
            'type' => 'function'
          },
          {
            'inputs' => [{ 'name' => 'anchorHash', 'type' => 'bytes32' }],
            'name' => 'verifyAnchor',
            'outputs' => [
              { 'name' => 'exists', 'type' => 'bool' },
              { 'name' => 'timestamp', 'type' => 'uint256' },
              { 'name' => 'anchorType', 'type' => 'string' },
              { 'name' => 'recorder', 'type' => 'address' }
            ],
            'stateMutability' => 'view',
            'type' => 'function'
          },
          {
            'inputs' => [{ 'name' => 'anchorHash', 'type' => 'bytes32' }],
            'name' => 'exists',
            'outputs' => [{ 'name' => '', 'type' => 'bool' }],
            'stateMutability' => 'view',
            'type' => 'function'
          },
          {
            'inputs' => [],
            'name' => 'totalAnchors',
            'outputs' => [{ 'name' => '', 'type' => 'uint256' }],
            'stateMutability' => 'view',
            'type' => 'function'
          }
        ]
      end

      def anchor_exists_on_chain?(hash)
        bytes32_hash = hash_to_bytes32(hash)
        @client.call(@contract, 'exists', bytes32_hash)
      end

      def call_contract_record(hash, anchor_type)
        bytes32_hash = hash_to_bytes32(hash)
        tx = @client.transact(
          @contract,
          'recordAnchor',
          bytes32_hash,
          anchor_type,
          sender_key: @key,
          gas_limit: DEFAULT_GAS_LIMIT
        )
        tx
      end

      def call_contract_batch_record(hashes, types)
        bytes32_hashes = hashes.map { |h| hash_to_bytes32(h) }
        tx = @client.transact(
          @contract,
          'recordAnchors',
          bytes32_hashes,
          types,
          sender_key: @key,
          gas_limit: BATCH_GAS_LIMIT
        )
        tx
      end

      def call_contract_verify(hash)
        bytes32_hash = hash_to_bytes32(hash)
        result = @client.call(@contract, 'verifyAnchor', bytes32_hash)

        {
          exists: result[0],
          timestamp: result[1].to_i,
          anchor_type: result[2],
          recorder: result[3]
        }
      end

      def call_contract_total_anchors
        @client.call(@contract, 'totalAnchors').to_i
      end

      def hash_to_bytes32(hash)
        # Convert hex string to bytes32
        [hash].pack('H*')
      end

      def mask_url(url)
        return nil unless url

        uri = URI.parse(url)
        if uri.userinfo
          "#{uri.scheme}://***@#{uri.host}:#{uri.port}#{uri.path}"
        else
          url
        end
      rescue URI::InvalidURIError
        '[invalid url]'
      end
    end
  end
end
