# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'

module HestiaChain
  module Core
    # Anchor represents a single proof-of-existence record.
    #
    # HestiaChain is designed as a generic "witness/anchor" module that can be used
    # across different applications (Meeting Protocol, GenomicsChain, etc.).
    #
    # An Anchor contains:
    # - anchor_type: The category of the anchor (meeting, genomics, research, etc.)
    # - source_id: A unique identifier from the source application
    # - data_hash: SHA256 hash of the data being anchored (never the data itself)
    # - participants: Optional list of involved parties
    # - metadata: Optional application-specific metadata
    # - timestamp: When the anchor was created
    # - previous_anchor_ref: Optional reference to a previous anchor (for chaining)
    #
    # Design Philosophy:
    # > "History is not replayable, but reconstructible through cooperation."
    #
    # @example Basic usage
    #   anchor = HestiaChain::Core::Anchor.new(
    #     anchor_type: 'research_data',
    #     source_id: 'experiment_001',
    #     data_hash: Digest::SHA256.hexdigest(data.to_json)
    #   )
    #
    # @example With participants and metadata
    #   anchor = HestiaChain::Core::Anchor.new(
    #     anchor_type: 'meeting',
    #     source_id: 'session_abc123',
    #     data_hash: session_hash,
    #     participants: ['agent_a', 'agent_b'],
    #     metadata: { message_count: 42, duration_seconds: 300 }
    #   )
    #
    class Anchor
      # Standard anchor types (custom types should use 'custom.' prefix)
      #
      # Core types:
      #   meeting, generic, genomics, research, agreement, audit, release
      #
      # Protocol types (opt-in, require 'hestia_chain/protocol'):
      #   philosophy_declaration, observation_log
      #
      STANDARD_TYPES = %w[
        meeting
        generic
        genomics
        research
        agreement
        audit
        release
        philosophy_declaration
        observation_log
      ].freeze

      attr_reader :anchor_type,
                  :source_id,
                  :data_hash,
                  :participants,
                  :metadata,
                  :timestamp,
                  :previous_anchor_ref

      # Create a new Anchor
      #
      # @param anchor_type [String] Category of the anchor
      # @param source_id [String] Unique identifier from the source application
      # @param data_hash [String] SHA256 hash of the data being anchored
      # @param participants [Array<String>] Optional list of involved parties
      # @param metadata [Hash] Optional application-specific metadata
      # @param timestamp [String] ISO8601 timestamp (defaults to current time)
      # @param previous_anchor_ref [String] Optional reference to previous anchor
      #
      # @raise [ArgumentError] If anchor_type is invalid
      # @raise [ArgumentError] If data_hash format is invalid
      #
      def initialize(anchor_type:, source_id:, data_hash:, **options)
        validate_type!(anchor_type)
        validate_data_hash!(data_hash)
        validate_source_id!(source_id)

        @anchor_type = anchor_type
        @source_id = source_id.to_s
        @data_hash = normalize_hash(data_hash)
        @participants = Array(options[:participants]).map(&:to_s).compact
        @metadata = options[:metadata] || {}
        @timestamp = options[:timestamp] || Time.now.utc.iso8601
        @previous_anchor_ref = options[:previous_anchor_ref]
      end

      # Calculate the unique hash for this anchor
      #
      # The anchor_hash is deterministically computed from all anchor fields
      # and serves as the unique identifier for verification on the blockchain.
      #
      # @return [String] SHA256 hex digest of the canonical payload
      #
      def anchor_hash
        @anchor_hash ||= Digest::SHA256.hexdigest(canonical_payload.to_json)
      end

      # Convert anchor to a hash representation
      #
      # @return [Hash] All anchor fields including computed anchor_hash
      #
      def to_h
        {
          anchor_type: @anchor_type,
          source_id: @source_id,
          data_hash: @data_hash,
          participants: @participants,
          metadata: @metadata,
          timestamp: @timestamp,
          previous_anchor_ref: @previous_anchor_ref,
          anchor_hash: anchor_hash
        }.compact
      end

      # Convert anchor to JSON
      #
      # @return [String] JSON representation
      #
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Create an Anchor from a hash (e.g., loaded from storage)
      #
      # @param hash [Hash] Anchor data
      # @return [Anchor] New Anchor instance
      #
      def self.from_h(hash)
        hash = hash.transform_keys(&:to_sym)
        new(
          anchor_type: hash[:anchor_type],
          source_id: hash[:source_id],
          data_hash: hash[:data_hash],
          participants: hash[:participants],
          metadata: hash[:metadata],
          timestamp: hash[:timestamp],
          previous_anchor_ref: hash[:previous_anchor_ref]
        )
      end

      # Check if this anchor has a valid hash
      #
      # @return [Boolean] True if anchor_hash matches computed hash
      #
      def valid?
        anchor_hash == Digest::SHA256.hexdigest(canonical_payload.to_json)
      end

      # Compare two anchors by their hash
      #
      # @param other [Anchor] Another anchor
      # @return [Boolean] True if anchor hashes match
      #
      def ==(other)
        return false unless other.is_a?(Anchor)

        anchor_hash == other.anchor_hash
      end
      alias eql? ==

      # Hash code for use in collections
      #
      # @return [Integer] Hash code based on anchor_hash
      #
      def hash
        anchor_hash.hash
      end

      # String representation
      #
      # @return [String] Human-readable representation
      #
      def inspect
        "#<HestiaChain::Anchor type=#{@anchor_type} source=#{@source_id} hash=#{anchor_hash[0, 16]}...>"
      end

      private

      # Generate canonical payload for hash computation
      #
      # The payload is sorted to ensure deterministic hash computation
      # regardless of the order fields were specified.
      #
      # @return [Hash] Canonical payload
      #
      def canonical_payload
        {
          t: @anchor_type,
          s: @source_id,
          d: @data_hash,
          p: @participants.sort,
          m: @metadata.sort.to_h,
          ts: @timestamp,
          prev: @previous_anchor_ref
        }
      end

      # Validate anchor type
      #
      # @param type [String] Anchor type to validate
      # @raise [ArgumentError] If type is invalid
      #
      def validate_type!(type)
        return if STANDARD_TYPES.include?(type)
        return if type.to_s.start_with?('custom.')

        raise ArgumentError,
              "Invalid anchor_type: '#{type}'. " \
              "Use one of #{STANDARD_TYPES.join(', ')} or 'custom.your_type'"
      end

      # Validate data hash format
      #
      # @param hash [String] Data hash to validate
      # @raise [ArgumentError] If hash format is invalid
      #
      def validate_data_hash!(hash)
        normalized = normalize_hash(hash)
        return if normalized.match?(/\A[a-f0-9]{64}\z/)

        raise ArgumentError,
              "Invalid data_hash format. Expected 64-character hex string (SHA256), " \
              "got: #{hash.inspect}"
      end

      # Validate source ID
      #
      # @param id [String] Source ID to validate
      # @raise [ArgumentError] If source ID is empty
      #
      def validate_source_id!(id)
        return unless id.nil? || id.to_s.strip.empty?

        raise ArgumentError, 'source_id cannot be empty'
      end

      # Normalize hash format (remove 0x prefix if present)
      #
      # @param hash [String] Hash to normalize
      # @return [String] Normalized hash (lowercase, no prefix)
      #
      def normalize_hash(hash)
        hash.to_s.downcase.sub(/\A0x/, '')
      end
    end
  end
end
