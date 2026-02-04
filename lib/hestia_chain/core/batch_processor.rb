# frozen_string_literal: true

require 'thread'

module HestiaChain
  module Core
    # BatchProcessor handles batching of anchors for efficient submission.
    #
    # When using public blockchains, submitting anchors individually is expensive.
    # BatchProcessor collects anchors and submits them in batches to optimize gas costs.
    #
    # @example Basic usage
    #   processor = BatchProcessor.new(backend, config)
    #   processor.enqueue(anchor1)
    #   processor.enqueue(anchor2)
    #   processor.flush!  # Submit all queued anchors
    #
    # @example With auto-flush
    #   processor = BatchProcessor.new(backend, config, auto_flush: true)
    #   processor.enqueue(anchor)  # Will auto-flush when threshold reached
    #
    class BatchProcessor
      attr_reader :queue_size

      # Create a new BatchProcessor
      #
      # @param backend [HestiaChain::Backend::Base] Backend to submit to
      # @param config [HestiaChain::Core::Config] Configuration
      # @param auto_flush [Boolean] Enable auto-flush when max_batch_size reached
      #
      def initialize(backend, config, auto_flush: false)
        @backend = backend
        @config = config
        @auto_flush = auto_flush
        @queue = []
        @mutex = Mutex.new
        @last_flush = Time.now.utc
        @stats = {
          total_enqueued: 0,
          total_flushed: 0,
          flush_count: 0
        }
      end

      # Enqueue an anchor for batch submission
      #
      # @param anchor [HestiaChain::Core::Anchor] Anchor to enqueue
      # @return [Hash] Enqueue result
      #
      def enqueue(anchor)
        result = nil

        @mutex.synchronize do
          @queue << anchor
          @stats[:total_enqueued] += 1

          result = {
            status: 'enqueued',
            anchor_hash: anchor.anchor_hash,
            queue_size: @queue.size,
            queue_position: @queue.size
          }
        end

        # Auto-flush if enabled and threshold reached
        if @auto_flush && should_flush?
          flush!
        end

        result
      end

      # Get current queue size
      #
      # @return [Integer] Number of anchors in queue
      #
      def queue_size
        @mutex.synchronize { @queue.size }
      end

      # Check if queue is empty
      #
      # @return [Boolean] True if queue is empty
      #
      def empty?
        queue_size.zero?
      end

      # Flush all queued anchors to the backend
      #
      # @return [Hash] Flush result
      #
      def flush!
        anchors_to_submit = nil

        @mutex.synchronize do
          return { status: 'empty', count: 0 } if @queue.empty?

          anchors_to_submit = @queue.dup
          @queue.clear
          @last_flush = Time.now.utc
          @stats[:flush_count] += 1
        end

        # Submit outside the mutex to avoid blocking
        result = @backend.submit_anchors(anchors_to_submit)

        @mutex.synchronize do
          @stats[:total_flushed] += anchors_to_submit.size
        end

        result.merge(
          flushed_at: @last_flush.iso8601,
          count: anchors_to_submit.size
        )
      rescue StandardError => e
        # Re-queue on failure
        @mutex.synchronize do
          @queue = anchors_to_submit + @queue
        end

        {
          status: 'error',
          error: e.message,
          requeued_count: anchors_to_submit.size
        }
      end

      # Check if batch should be flushed
      #
      # @return [Boolean] True if flush conditions are met
      #
      def should_flush?
        return false unless @config.batching_enabled?

        @mutex.synchronize do
          # Flush if max batch size reached
          return true if @queue.size >= @config.max_batch_size

          # Flush if interval elapsed
          elapsed = Time.now.utc - @last_flush
          return true if elapsed >= @config.batch_interval

          false
        end
      end

      # Get batch processor statistics
      #
      # @return [Hash] Statistics
      #
      def stats
        @mutex.synchronize do
          @stats.merge(
            current_queue_size: @queue.size,
            last_flush: @last_flush.iso8601,
            batching_enabled: @config.batching_enabled?,
            max_batch_size: @config.max_batch_size,
            batch_interval: @config.batch_interval
          )
        end
      end

      # Peek at queued anchors (without removing)
      #
      # @param limit [Integer] Maximum number to return
      # @return [Array<Hash>] Queued anchor summaries
      #
      def peek(limit: 10)
        @mutex.synchronize do
          @queue.first(limit).map do |anchor|
            {
              anchor_hash: anchor.anchor_hash,
              anchor_type: anchor.anchor_type,
              source_id: anchor.source_id,
              timestamp: anchor.timestamp
            }
          end
        end
      end

      # Clear the queue without submitting
      #
      # @return [Integer] Number of anchors cleared
      #
      def clear!
        @mutex.synchronize do
          count = @queue.size
          @queue.clear
          count
        end
      end
    end
  end
end
