# frozen_string_literal: true

require_relative 'base'
require 'digest'

module HestiaChain
  module Integrations
    # Generic integration for HestiaChain.
    #
    # This integration provides a simple interface for anchoring any type of data.
    # Use this when you don't need application-specific logic.
    #
    # @example Basic usage
    #   client = HestiaChain.client
    #   integration = HestiaChain::Integrations::Generic.new(
    #     client: client,
    #     anchor_type: 'research_data'
    #   )
    #
    #   # Anchor some data
    #   integration.anchor(
    #     source_id: 'experiment_001',
    #     data: { result: 'success', value: 42 }
    #   )
    #
    class Generic < Base
      DEFAULT_ANCHOR_TYPE = 'generic'

      attr_reader :anchor_type

      # Create a new generic integration
      #
      # @param client [HestiaChain::Core::Client] HestiaChain client
      # @param anchor_type [String] Default anchor type for this integration
      #
      def initialize(client:, anchor_type: DEFAULT_ANCHOR_TYPE)
        super(client: client)
        @anchor_type = anchor_type
      end

      # Anchor any data
      #
      # @param source_id [String] Unique identifier for this anchor
      # @param data [String, Hash] Data to anchor (will be hashed)
      # @param participants [Array<String>] Optional list of participants
      # @param metadata [Hash] Optional metadata
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def anchor(source_id:, data:, participants: [], metadata: {}, async: false)
        anchor_obj = build_anchor(
          anchor_type: @anchor_type,
          source_id: source_id,
          data: data,
          participants: participants,
          metadata: metadata
        )

        @client.submit(anchor_obj, async: async)
      end

      # Anchor raw hash (when you've already computed the hash)
      #
      # @param source_id [String] Unique identifier
      # @param data_hash [String] Pre-computed SHA256 hash
      # @param participants [Array<String>] Optional participants
      # @param metadata [Hash] Optional metadata
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def anchor_hash(source_id:, data_hash:, participants: [], metadata: {}, async: false)
        anchor_obj = HestiaChain::Core::Anchor.new(
          anchor_type: @anchor_type,
          source_id: source_id,
          data_hash: data_hash,
          participants: participants,
          metadata: metadata
        )

        @client.submit(anchor_obj, async: async)
      end

      # Verify an anchor by source_id
      #
      # @param source_id [String] Source ID to search for
      # @param data [String, Hash, nil] Optional data to verify hash against
      # @return [Hash] Verification result
      #
      def verify_by_source(source_id, data: nil)
        anchors = @client.list(anchor_type: @anchor_type, limit: 1000)
        anchor = anchors.find { |a| a[:source_id] == source_id }

        return { exists: false, source_id: source_id } unless anchor

        result = {
          exists: true,
          source_id: source_id,
          anchor_hash: anchor[:anchor_hash],
          data_hash: anchor[:data_hash],
          timestamp: anchor[:timestamp]
        }

        if data
          expected_hash = calculate_hash(data)
          result[:data_matches] = anchor[:data_hash] == expected_hash
        end

        result
      end

      # List all anchors of this type
      #
      # @param limit [Integer] Maximum number of results
      # @param since [String] Filter by timestamp (ISO8601)
      # @return [Array<Hash>] Anchors
      #
      def list(limit: 100, since: nil)
        @client.list(anchor_type: @anchor_type, limit: limit, since: since)
      end

      # Get statistics for this anchor type
      #
      # @return [Hash] Statistics
      #
      def type_stats
        all = list(limit: 10_000)
        unique_sources = all.map { |a| a[:source_id] }.uniq

        {
          anchor_type: @anchor_type,
          total_anchors: all.size,
          unique_sources: unique_sources.size
        }
      end
    end
  end
end
