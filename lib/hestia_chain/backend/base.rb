# frozen_string_literal: true

module HestiaChain
  module Backend
    # Base is the abstract base class for all HestiaChain backends.
    #
    # Backends are responsible for storing and retrieving anchors.
    # HestiaChain supports multiple backend types for different deployment stages:
    #
    # - InMemory (Stage 0): For development and testing
    # - Private (Stage 1): JSON file-based storage
    # - PublicTestnet (Stage 2): Ethereum testnet (e.g., Base Sepolia)
    # - PublicMainnet (Stage 3): Ethereum mainnet (e.g., Base, Ethereum)
    #
    # @abstract Subclass and implement the abstract methods
    #
    class Base
      attr_reader :config

      # Create a new backend instance
      #
      # @param config [HestiaChain::Core::Config] Configuration object
      #
      def initialize(config)
        @config = config
      end

      # Submit an anchor to the backend
      #
      # @param anchor [HestiaChain::Core::Anchor] Anchor to submit
      # @return [Hash] Result with :status, :anchor_hash, and backend-specific fields
      #
      # @abstract
      #
      def submit_anchor(anchor)
        raise NotImplementedError, "#{self.class}#submit_anchor must be implemented"
      end

      # Submit multiple anchors in a batch
      #
      # @param anchors [Array<HestiaChain::Core::Anchor>] Anchors to submit
      # @return [Hash] Result with :status, :count, :anchor_hashes
      #
      def submit_anchors(anchors)
        results = anchors.map { |anchor| submit_anchor(anchor) }
        {
          status: 'submitted',
          count: results.size,
          anchor_hashes: results.map { |r| r[:anchor_hash] },
          results: results
        }
      end

      # Verify an anchor exists in the backend
      #
      # @param anchor_hash [String] Anchor hash to verify
      # @return [Hash] Result with :exists, :timestamp, :anchor_type (if found)
      #
      # @abstract
      #
      def verify_anchor(anchor_hash)
        raise NotImplementedError, "#{self.class}#verify_anchor must be implemented"
      end

      # Get an anchor by its hash
      #
      # @param anchor_hash [String] Anchor hash to retrieve
      # @return [Hash, nil] Anchor data or nil if not found
      #
      # @abstract
      #
      def get_anchor(anchor_hash)
        raise NotImplementedError, "#{self.class}#get_anchor must be implemented"
      end

      # List anchors with optional filtering
      #
      # @param limit [Integer] Maximum number of anchors to return
      # @param anchor_type [String, nil] Filter by anchor type
      # @param since [String, nil] Filter by timestamp (ISO8601)
      # @return [Array<Hash>] List of anchor data
      #
      # @abstract
      #
      def list_anchors(limit: 100, anchor_type: nil, since: nil)
        raise NotImplementedError, "#{self.class}#list_anchors must be implemented"
      end

      # Get the backend type
      #
      # @return [Symbol] Backend type (:in_memory, :private, :public_testnet, :public_mainnet)
      #
      # @abstract
      #
      def backend_type
        raise NotImplementedError, "#{self.class}#backend_type must be implemented"
      end

      # Check if the backend is ready
      #
      # @return [Boolean] True if ready to accept anchors
      #
      # @abstract
      #
      def ready?
        raise NotImplementedError, "#{self.class}#ready? must be implemented"
      end

      # Get backend statistics
      #
      # @return [Hash] Statistics (total_anchors, etc.)
      #
      def stats
        {
          backend_type: backend_type,
          ready: ready?
        }
      end

      # Factory method to create a backend from configuration
      #
      # @param config [HestiaChain::Core::Config] Configuration object
      # @return [Base] Backend instance
      # @raise [ArgumentError] If backend type is unknown
      #
      def self.create(config)
        case config.backend
        when 'in_memory'
          require_relative 'in_memory'
          InMemory.new(config)
        when 'private'
          require_relative 'private'
          Private.new(config)
        when 'public_testnet'
          require_relative 'public_testnet'
          PublicTestnet.new(config)
        when 'public_mainnet'
          require_relative 'public_mainnet'
          PublicMainnet.new(config)
        else
          raise ArgumentError, "Unknown backend type: #{config.backend}. " \
                               "Valid types: in_memory, private, public_testnet, public_mainnet"
        end
      end

      protected

      # Normalize anchor hash (remove 0x prefix, lowercase)
      #
      # @param hash [String] Anchor hash
      # @return [String] Normalized hash
      #
      def normalize_hash(hash)
        hash.to_s.downcase.sub(/\A0x/, '')
      end

      # Validate anchor is a valid Anchor instance
      #
      # @param anchor [Object] Object to validate
      # @raise [ArgumentError] If not a valid Anchor
      #
      def validate_anchor!(anchor)
        return if anchor.is_a?(HestiaChain::Core::Anchor)

        raise ArgumentError, "Expected HestiaChain::Core::Anchor, got #{anchor.class}"
      end
    end
  end
end
