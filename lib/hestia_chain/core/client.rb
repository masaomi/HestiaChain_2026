# frozen_string_literal: true

require_relative 'anchor'
require_relative 'config'
require_relative 'batch_processor'
require_relative '../backend/base'

module HestiaChain
  module Core
    # Client is the main interface for interacting with HestiaChain.
    #
    # The Client provides a high-level API for submitting, verifying, and
    # retrieving anchors. It automatically handles backend selection and
    # batch processing based on configuration.
    #
    # @example Basic usage
    #   client = HestiaChain::Core::Client.new
    #
    #   anchor = HestiaChain::Core::Anchor.new(
    #     anchor_type: 'research_data',
    #     source_id: 'experiment_001',
    #     data_hash: Digest::SHA256.hexdigest(data.to_json)
    #   )
    #
    #   result = client.submit(anchor)
    #   puts result[:anchor_hash]
    #
    # @example With async batching
    #   client = HestiaChain::Core::Client.new
    #   client.submit(anchor, async: true)  # Queues for batch submission
    #   client.flush_batch!                  # Submit all queued anchors
    #
    # @example Verification
    #   result = client.verify(anchor_hash)
    #   puts "Anchor exists!" if result[:exists]
    #
    class Client
      attr_reader :config, :backend

      # Create a new Client
      #
      # @param config [Config, Hash, nil] Configuration (loads from file if nil)
      # @param backend [Backend::Base, nil] Backend (created from config if nil)
      #
      def initialize(config: nil, backend: nil)
        @config = case config
                  when Config then config
                  when Hash then Config.new(config)
                  else Config.load
                  end

        @backend = backend || Backend::Base.create(@config)
        @batch_processor = BatchProcessor.new(@backend, @config, auto_flush: false)
      end

      # Submit an anchor
      #
      # @param anchor [Anchor] Anchor to submit
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      # @example Synchronous submission
      #   result = client.submit(anchor)
      #   # => { status: 'submitted', anchor_hash: '...', backend: 'in_memory' }
      #
      # @example Asynchronous (batched) submission
      #   result = client.submit(anchor, async: true)
      #   # => { status: 'enqueued', anchor_hash: '...', queue_size: 1 }
      #
      def submit(anchor, async: false)
        validate_anchor!(anchor)
        return { status: 'disabled', message: 'HestiaChain is disabled' } unless @config.enabled?

        if async && @config.batching_enabled?
          @batch_processor.enqueue(anchor)
        else
          @backend.submit_anchor(anchor)
        end
      end

      # Submit multiple anchors
      #
      # @param anchors [Array<Anchor>] Anchors to submit
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def submit_all(anchors, async: false)
        return { status: 'disabled', message: 'HestiaChain is disabled' } unless @config.enabled?

        anchors.each { |a| validate_anchor!(a) }

        if async && @config.batching_enabled?
          anchors.each { |a| @batch_processor.enqueue(a) }
          {
            status: 'enqueued',
            count: anchors.size,
            queue_size: @batch_processor.queue_size
          }
        else
          @backend.submit_anchors(anchors)
        end
      end

      # Verify an anchor exists
      #
      # @param anchor_hash [String] Anchor hash to verify
      # @return [Hash] Verification result
      #
      # @example
      #   result = client.verify('abc123...')
      #   # => { exists: true, anchor_type: 'meeting', timestamp: '2026-02-03T...' }
      #
      def verify(anchor_hash)
        @backend.verify_anchor(anchor_hash)
      end

      # Get an anchor by hash
      #
      # @param anchor_hash [String] Anchor hash
      # @return [Hash, nil] Anchor data or nil
      #
      def get(anchor_hash)
        @backend.get_anchor(anchor_hash)
      end

      # List anchors with optional filtering
      #
      # @param limit [Integer] Maximum number of anchors
      # @param anchor_type [String, nil] Filter by type
      # @param since [String, nil] Filter by timestamp (ISO8601)
      # @return [Array<Hash>] List of anchors
      #
      def list(limit: 100, anchor_type: nil, since: nil)
        @backend.list_anchors(limit: limit, anchor_type: anchor_type, since: since)
      end

      # Flush the batch queue
      #
      # @return [Hash] Flush result
      #
      def flush_batch!
        @batch_processor.flush!
      end

      # Get current batch queue size
      #
      # @return [Integer] Number of anchors in queue
      #
      def batch_queue_size
        @batch_processor.queue_size
      end

      # Peek at queued anchors
      #
      # @param limit [Integer] Maximum number to return
      # @return [Array<Hash>] Queued anchor summaries
      #
      def peek_batch(limit: 10)
        @batch_processor.peek(limit: limit)
      end

      # Get backend type
      #
      # @return [Symbol] Backend type
      #
      def backend_type
        @backend.backend_type
      end

      # Get client status
      #
      # @return [Hash] Status information
      #
      def status
        {
          enabled: @config.enabled?,
          backend: backend_type,
          backend_ready: @backend.ready?,
          batching_enabled: @config.batching_enabled?,
          batch_queue_size: @batch_processor.queue_size
        }
      end

      # Get detailed statistics
      #
      # @return [Hash] Statistics from backend and batch processor
      #
      def stats
        {
          client: status,
          backend: @backend.stats,
          batch_processor: @batch_processor.stats
        }
      end

      # String representation
      #
      # @return [String] Client summary
      #
      def inspect
        "#<HestiaChain::Client backend=#{backend_type} enabled=#{@config.enabled?}>"
      end

      # Create a simple anchor and submit it
      #
      # Convenience method for simple use cases.
      #
      # @param anchor_type [String] Anchor type
      # @param source_id [String] Source identifier
      # @param data [String, Hash] Data to hash
      # @param options [Hash] Additional anchor options
      # @return [Hash] Submission result
      #
      def anchor(anchor_type:, source_id:, data:, **options)
        data_hash = case data
                    when String then Digest::SHA256.hexdigest(data)
                    when Hash then Digest::SHA256.hexdigest(data.to_json)
                    else raise ArgumentError, "Data must be String or Hash"
                    end

        anchor = Anchor.new(
          anchor_type: anchor_type,
          source_id: source_id,
          data_hash: data_hash,
          **options
        )

        submit(anchor, async: options.delete(:async) || false)
      end

      private

      # Validate anchor is a valid Anchor instance
      #
      # @param anchor [Object] Object to validate
      # @raise [ArgumentError] If not a valid Anchor
      #
      def validate_anchor!(anchor)
        return if anchor.is_a?(Anchor)

        raise ArgumentError, "Expected HestiaChain::Core::Anchor, got #{anchor.class}"
      end
    end
  end
end
