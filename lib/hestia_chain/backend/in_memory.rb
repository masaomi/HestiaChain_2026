# frozen_string_literal: true

require_relative 'base'

module HestiaChain
  module Backend
    # InMemory backend stores anchors in memory.
    #
    # This backend is designed for:
    # - Development and testing
    # - Proof of concept implementations
    # - Unit tests
    #
    # WARNING: Data is lost when the process exits.
    #
    # @example Basic usage
    #   config = HestiaChain::Core::Config.new(backend: 'in_memory')
    #   backend = HestiaChain::Backend::InMemory.new(config)
    #
    #   anchor = HestiaChain::Core::Anchor.new(
    #     anchor_type: 'test',
    #     source_id: 'test_001',
    #     data_hash: Digest::SHA256.hexdigest('test data')
    #   )
    #
    #   backend.submit_anchor(anchor)
    #   backend.verify_anchor(anchor.anchor_hash)
    #
    class InMemory < Base
      def initialize(config)
        super
        @anchors = {}
        @mutex = Mutex.new
        @created_at = Time.now.utc
      end

      # Submit an anchor to memory
      #
      # @param anchor [HestiaChain::Core::Anchor] Anchor to submit
      # @return [Hash] Result with status and anchor_hash
      #
      def submit_anchor(anchor)
        validate_anchor!(anchor)
        hash = normalize_hash(anchor.anchor_hash)

        @mutex.synchronize do
          if @anchors.key?(hash)
            return {
              status: 'exists',
              anchor_hash: hash,
              message: 'Anchor already exists'
            }
          end

          @anchors[hash] = {
            anchor_hash: hash,
            anchor_type: anchor.anchor_type,
            source_id: anchor.source_id,
            data_hash: anchor.data_hash,
            participants: anchor.participants,
            metadata: anchor.metadata,
            timestamp: anchor.timestamp,
            previous_anchor_ref: anchor.previous_anchor_ref,
            stored_at: Time.now.utc.iso8601
          }
        end

        {
          status: 'submitted',
          anchor_hash: hash,
          backend: 'in_memory'
        }
      end

      # Verify an anchor exists
      #
      # @param anchor_hash [String] Anchor hash to verify
      # @return [Hash] Verification result
      #
      def verify_anchor(anchor_hash)
        hash = normalize_hash(anchor_hash)

        @mutex.synchronize do
          anchor = @anchors[hash]

          if anchor
            {
              exists: true,
              anchor_hash: hash,
              anchor_type: anchor[:anchor_type],
              timestamp: anchor[:timestamp],
              stored_at: anchor[:stored_at]
            }
          else
            {
              exists: false,
              anchor_hash: hash
            }
          end
        end
      end

      # Get an anchor by hash
      #
      # @param anchor_hash [String] Anchor hash
      # @return [Hash, nil] Anchor data or nil
      #
      def get_anchor(anchor_hash)
        hash = normalize_hash(anchor_hash)

        @mutex.synchronize do
          @anchors[hash]&.dup
        end
      end

      # List anchors with filtering
      #
      # @param limit [Integer] Maximum number of anchors
      # @param anchor_type [String, nil] Filter by type
      # @param since [String, nil] Filter by timestamp
      # @return [Array<Hash>] List of anchors
      #
      def list_anchors(limit: 100, anchor_type: nil, since: nil)
        @mutex.synchronize do
          anchors = @anchors.values

          # Filter by type
          anchors = anchors.select { |a| a[:anchor_type] == anchor_type } if anchor_type

          # Filter by timestamp
          if since
            since_time = Time.parse(since)
            anchors = anchors.select { |a| Time.parse(a[:timestamp]) >= since_time }
          end

          # Sort by timestamp (newest first) and limit
          anchors
            .sort_by { |a| a[:timestamp] }
            .reverse
            .first(limit)
        end
      end

      # Get backend type
      #
      # @return [Symbol] :in_memory
      #
      def backend_type
        :in_memory
      end

      # Check if backend is ready
      #
      # @return [Boolean] Always true for in-memory
      #
      def ready?
        true
      end

      # Get statistics
      #
      # @return [Hash] Backend statistics
      #
      def stats
        @mutex.synchronize do
          types = @anchors.values.group_by { |a| a[:anchor_type] }

          super.merge(
            total_anchors: @anchors.size,
            anchors_by_type: types.transform_values(&:count),
            created_at: @created_at.iso8601,
            note: 'Data is stored in memory only and will be lost on restart'
          )
        end
      end

      # Clear all anchors (for testing)
      #
      # @return [Integer] Number of anchors cleared
      #
      def clear!
        @mutex.synchronize do
          count = @anchors.size
          @anchors.clear
          count
        end
      end

      # Get anchor count
      #
      # @return [Integer] Number of anchors stored
      #
      def count
        @mutex.synchronize { @anchors.size }
      end
    end
  end
end
