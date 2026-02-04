# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'
require_relative 'types'

module HestiaChain
  module Protocol
    # PhilosophyDeclaration represents an agent's declaration of their exchange philosophy.
    #
    # This is NOT about reaching consensus or agreement. It is about making
    # one's philosophical stance observable to other agents. Each agent
    # interprets these declarations according to their own philosophy.
    #
    # Design Philosophy (Beyond DAO):
    # > "Skill exchange is an experiment in observing another agent's philosophy."
    #
    # A philosophy declaration does NOT:
    # - Enforce any behavior on other agents
    # - Require agreement or consensus
    # - Judge other philosophies as right or wrong
    #
    # A philosophy declaration DOES:
    # - Make the agent's stance observable
    # - Enable other agents to decide compatibility locally
    # - Support evolution over time (via versioning)
    #
    # @example Declaring an exchange philosophy
    #   declaration = HestiaChain::Protocol::PhilosophyDeclaration.new(
    #     agent_id: 'kairos_agent_001',
    #     philosophy_type: 'exchange',
    #     philosophy_hash: Digest::SHA256.hexdigest(philosophy_content.to_json),
    #     compatible_with: ['cooperative', 'observational'],
    #     version: '1.0'
    #   )
    #
    #   # Submit to HestiaChain
    #   client.submit(declaration.to_anchor)
    #
    class PhilosophyDeclaration
      attr_reader :agent_id,
                  :philosophy_type,
                  :philosophy_hash,
                  :compatible_with,
                  :version,
                  :timestamp,
                  :previous_declaration_ref,
                  :metadata

      # Create a new PhilosophyDeclaration
      #
      # @param agent_id [String] Identifier of the declaring agent
      # @param philosophy_type [String] Type of philosophy (exchange, interaction, fadeout)
      # @param philosophy_hash [String] SHA256 hash of the philosophy content (content stays private)
      # @param compatible_with [Array<String>] Compatibility tags (cooperative, competitive, etc.)
      # @param version [String] Version of this philosophy declaration
      # @param timestamp [String] ISO8601 timestamp (defaults to current time)
      # @param previous_declaration_ref [String] Reference to previous declaration (for evolution tracking)
      # @param metadata [Hash] Additional metadata
      #
      # @raise [ArgumentError] If required fields are missing or invalid
      #
      def initialize(agent_id:, philosophy_type:, philosophy_hash:, **options)
        validate_agent_id!(agent_id)
        validate_philosophy_type!(philosophy_type)
        validate_philosophy_hash!(philosophy_hash)

        @agent_id = agent_id.to_s
        @philosophy_type = philosophy_type.to_s
        @philosophy_hash = normalize_hash(philosophy_hash)
        @compatible_with = Array(options[:compatible_with]).map(&:to_s).compact
        @version = options[:version]&.to_s || '1.0'
        @timestamp = options[:timestamp] || Time.now.utc.iso8601
        @previous_declaration_ref = options[:previous_declaration_ref]
        @metadata = options[:metadata] || {}
      end

      # Generate a unique identifier for this declaration
      #
      # @return [String] Unique declaration ID
      #
      def declaration_id
        @declaration_id ||= "philo_#{@agent_id}_#{@philosophy_type}_#{@version}_#{@timestamp.gsub(/[^0-9]/, '')}"
      end

      # Convert to a HestiaChain Anchor
      #
      # This allows the declaration to be submitted through the standard
      # HestiaChain client interface.
      #
      # @return [HestiaChain::Core::Anchor] Anchor representation
      #
      def to_anchor
        require_relative '../core/anchor'

        Core::Anchor.new(
          anchor_type: 'philosophy_declaration',
          source_id: declaration_id,
          data_hash: @philosophy_hash,
          participants: [@agent_id],
          metadata: anchor_metadata,
          timestamp: @timestamp,
          previous_anchor_ref: @previous_declaration_ref
        )
      end

      # Convert to hash representation
      #
      # @return [Hash] All declaration fields
      #
      def to_h
        {
          agent_id: @agent_id,
          philosophy_type: @philosophy_type,
          philosophy_hash: @philosophy_hash,
          compatible_with: @compatible_with,
          version: @version,
          timestamp: @timestamp,
          previous_declaration_ref: @previous_declaration_ref,
          metadata: @metadata,
          declaration_id: declaration_id
        }.compact
      end

      # Convert to JSON
      #
      # @return [String] JSON representation
      #
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Create from hash (e.g., loaded from storage)
      #
      # @param hash [Hash] Declaration data
      # @return [PhilosophyDeclaration] New instance
      #
      def self.from_h(hash)
        hash = hash.transform_keys(&:to_sym)
        new(
          agent_id: hash[:agent_id],
          philosophy_type: hash[:philosophy_type],
          philosophy_hash: hash[:philosophy_hash],
          compatible_with: hash[:compatible_with],
          version: hash[:version],
          timestamp: hash[:timestamp],
          previous_declaration_ref: hash[:previous_declaration_ref],
          metadata: hash[:metadata]
        )
      end

      # String representation
      #
      # @return [String] Human-readable representation
      #
      def inspect
        "#<HestiaChain::Protocol::PhilosophyDeclaration " \
          "agent=#{@agent_id} type=#{@philosophy_type} version=#{@version}>"
      end

      private

      # Generate metadata for the anchor
      #
      # @return [Hash] Metadata hash
      #
      def anchor_metadata
        {
          philosophy_type: @philosophy_type,
          compatible_with: @compatible_with,
          version: @version
        }.merge(@metadata)
      end

      # Validate agent ID
      #
      # @param id [String] Agent ID to validate
      # @raise [ArgumentError] If agent ID is empty
      #
      def validate_agent_id!(id)
        return unless id.nil? || id.to_s.strip.empty?

        raise ArgumentError, 'agent_id cannot be empty'
      end

      # Validate philosophy type
      #
      # @param type [String] Philosophy type to validate
      # @raise [ArgumentError] If type is invalid
      #
      def validate_philosophy_type!(type)
        return if Types::PHILOSOPHY_TYPES.include?(type.to_s)
        return if type.to_s.start_with?('custom.')

        raise ArgumentError,
              "Invalid philosophy_type: '#{type}'. " \
              "Use one of #{Types::PHILOSOPHY_TYPES.join(', ')} or 'custom.your_type'"
      end

      # Validate philosophy hash format
      #
      # @param hash [String] Hash to validate
      # @raise [ArgumentError] If hash format is invalid
      #
      def validate_philosophy_hash!(hash)
        normalized = normalize_hash(hash)
        return if normalized.match?(/\A[a-f0-9]{64}\z/)

        raise ArgumentError,
              "Invalid philosophy_hash format. Expected 64-character hex string (SHA256), " \
              "got: #{hash.inspect}"
      end

      # Normalize hash format
      #
      # @param hash [String] Hash to normalize
      # @return [String] Normalized hash (lowercase, no 0x prefix)
      #
      def normalize_hash(hash)
        hash.to_s.downcase.sub(/\A0x/, '')
      end
    end
  end
end
