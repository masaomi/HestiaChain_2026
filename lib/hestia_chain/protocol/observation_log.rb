# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'
require_relative 'types'

module HestiaChain
  module Protocol
    # ObservationLog represents a record of an observed interaction between agents.
    #
    # This is explicitly an OBSERVATION, not an EVALUATION. The same interaction
    # can have multiple observation logs from different observers, each with
    # their own interpretation. There is no universal truth about the interaction.
    #
    # Design Philosophy (Beyond DAO):
    # > "Meaning is not agreed upon. Meaning coexists."
    #
    # Key principles:
    # - Observations are subjective to the observer
    # - Multiple interpretations of the same interaction are valid
    # - No forced resolution of contradictions
    # - Fade-out is a legitimate outcome, not a failure
    #
    # @example Recording an observation
    #   observation = HestiaChain::Protocol::ObservationLog.new(
    #     observer_id: 'kairos_agent_001',
    #     observed_id: 'kairos_agent_002',
    #     interaction_hash: Digest::SHA256.hexdigest(interaction_data.to_json),
    #     observation_type: 'completed',
    #     interpretation: {
    #       outcome: 'mutual_learning',
    #       compatibility: 'high',
    #       notes: 'Philosophies aligned on key exchange principles'
    #     }
    #   )
    #
    #   # Submit to HestiaChain
    #   client.submit(observation.to_anchor)
    #
    class ObservationLog
      attr_reader :observer_id,
                  :observed_id,
                  :interaction_hash,
                  :observation_type,
                  :interpretation,
                  :timestamp,
                  :context_ref,
                  :metadata

      # Create a new ObservationLog
      #
      # @param observer_id [String] ID of the agent making the observation
      # @param observed_id [String] ID of the agent being observed (can be same as observer for self-observation)
      # @param interaction_hash [String] SHA256 hash of the interaction data (data stays private)
      # @param observation_type [String] Type of observation (initiated, completed, faded, observed)
      # @param interpretation [Hash] Observer's interpretation (subjective, not universal)
      # @param timestamp [String] ISO8601 timestamp (defaults to current time)
      # @param context_ref [String] Optional reference to related context (e.g., philosophy declaration)
      # @param metadata [Hash] Additional metadata
      #
      # @raise [ArgumentError] If required fields are missing or invalid
      #
      def initialize(observer_id:, observed_id:, interaction_hash:, observation_type:, **options)
        validate_observer_id!(observer_id)
        validate_observed_id!(observed_id)
        validate_interaction_hash!(interaction_hash)
        validate_observation_type!(observation_type)

        @observer_id = observer_id.to_s
        @observed_id = observed_id.to_s
        @interaction_hash = normalize_hash(interaction_hash)
        @observation_type = observation_type.to_s
        @interpretation = options[:interpretation] || {}
        @timestamp = options[:timestamp] || Time.now.utc.iso8601
        @context_ref = options[:context_ref]
        @metadata = options[:metadata] || {}
      end

      # Generate a unique identifier for this observation
      #
      # @return [String] Unique observation ID
      #
      def observation_id
        @observation_id ||= begin
          hash_input = "#{@observer_id}_#{@observed_id}_#{@interaction_hash}_#{@timestamp}"
          short_hash = Digest::SHA256.hexdigest(hash_input)[0, 12]
          "obs_#{short_hash}"
        end
      end

      # Check if this is a self-observation
      #
      # @return [Boolean] True if observer and observed are the same
      #
      def self_observation?
        @observer_id == @observed_id
      end

      # Check if this observation records a fade-out
      #
      # @return [Boolean] True if observation_type is 'faded'
      #
      def fadeout?
        @observation_type == 'faded'
      end

      # Convert to a HestiaChain Anchor
      #
      # This allows the observation to be submitted through the standard
      # HestiaChain client interface.
      #
      # @return [HestiaChain::Core::Anchor] Anchor representation
      #
      def to_anchor
        require_relative '../core/anchor'

        participants = [@observer_id]
        participants << @observed_id unless self_observation?

        Core::Anchor.new(
          anchor_type: 'observation_log',
          source_id: observation_id,
          data_hash: @interaction_hash,
          participants: participants.uniq,
          metadata: anchor_metadata,
          timestamp: @timestamp,
          previous_anchor_ref: @context_ref
        )
      end

      # Convert to hash representation
      #
      # @return [Hash] All observation fields
      #
      def to_h
        {
          observer_id: @observer_id,
          observed_id: @observed_id,
          interaction_hash: @interaction_hash,
          observation_type: @observation_type,
          interpretation: @interpretation,
          timestamp: @timestamp,
          context_ref: @context_ref,
          metadata: @metadata,
          observation_id: observation_id
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
      # @param hash [Hash] Observation data
      # @return [ObservationLog] New instance
      #
      def self.from_h(hash)
        hash = hash.transform_keys(&:to_sym)
        new(
          observer_id: hash[:observer_id],
          observed_id: hash[:observed_id],
          interaction_hash: hash[:interaction_hash],
          observation_type: hash[:observation_type],
          interpretation: hash[:interpretation],
          timestamp: hash[:timestamp],
          context_ref: hash[:context_ref],
          metadata: hash[:metadata]
        )
      end

      # String representation
      #
      # @return [String] Human-readable representation
      #
      def inspect
        relation = self_observation? ? 'self' : "#{@observer_id}->#{@observed_id}"
        "#<HestiaChain::Protocol::ObservationLog " \
          "type=#{@observation_type} relation=#{relation}>"
      end

      private

      # Generate metadata for the anchor
      #
      # @return [Hash] Metadata hash
      #
      def anchor_metadata
        base = {
          observation_type: @observation_type,
          observer_id: @observer_id,
          observed_id: @observed_id
        }

        # Include interpretation hash (not the interpretation itself) for verifiability
        unless @interpretation.empty?
          base[:interpretation_hash] = Digest::SHA256.hexdigest(@interpretation.to_json)
        end

        base.merge(@metadata)
      end

      # Validate observer ID
      #
      # @param id [String] Observer ID to validate
      # @raise [ArgumentError] If observer ID is empty
      #
      def validate_observer_id!(id)
        return unless id.nil? || id.to_s.strip.empty?

        raise ArgumentError, 'observer_id cannot be empty'
      end

      # Validate observed ID
      #
      # @param id [String] Observed ID to validate
      # @raise [ArgumentError] If observed ID is empty
      #
      def validate_observed_id!(id)
        return unless id.nil? || id.to_s.strip.empty?

        raise ArgumentError, 'observed_id cannot be empty'
      end

      # Validate observation type
      #
      # @param type [String] Observation type to validate
      # @raise [ArgumentError] If type is invalid
      #
      def validate_observation_type!(type)
        return if Types::OBSERVATION_TYPES.include?(type.to_s)
        return if type.to_s.start_with?('custom.')

        raise ArgumentError,
              "Invalid observation_type: '#{type}'. " \
              "Use one of #{Types::OBSERVATION_TYPES.join(', ')} or 'custom.your_type'"
      end

      # Validate interaction hash format
      #
      # @param hash [String] Hash to validate
      # @raise [ArgumentError] If hash format is invalid
      #
      def validate_interaction_hash!(hash)
        normalized = normalize_hash(hash)
        return if normalized.match?(/\A[a-f0-9]{64}\z/)

        raise ArgumentError,
              "Invalid interaction_hash format. Expected 64-character hex string (SHA256), " \
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
