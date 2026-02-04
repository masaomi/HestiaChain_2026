# frozen_string_literal: true

require_relative 'base'
require 'digest'

module HestiaChain
  module Integrations
    # MeetingProtocol integration for HestiaChain.
    #
    # This integration provides methods to anchor Meeting Protocol (MMP) events:
    # - Session completions (from InteractionLog)
    # - Relay operations (from AuditLogger)
    # - Skill exchanges
    #
    # Design Philosophy:
    # > "History is not replayable, but reconstructible through cooperation."
    #
    # Only hashes are recorded, never actual content. Multiple agents'
    # cooperation is required to reconstruct the full history.
    #
    # @example Basic usage
    #   client = HestiaChain.client
    #   integration = HestiaChain::Integrations::MeetingProtocol.new(client: client)
    #
    #   # Anchor a session
    #   integration.anchor_session(session_data)
    #
    #   # Query peer history
    #   integration.peer_history('agent_abc123')
    #
    class MeetingProtocol < Base
      ANCHOR_TYPE = 'meeting'

      # Anchor a completed session from InteractionLog
      #
      # @param session [Hash] Session data with keys:
      #   - :session_id [String] Unique session identifier
      #   - :peer_id [String] Peer's instance_id
      #   - :started_at [String] ISO8601 timestamp
      #   - :ended_at [String] ISO8601 timestamp (optional)
      #   - :messages [Array<Hash>] Session messages
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def anchor_session(session, async: false)
        validate_session!(session)

        anchor = build_session_anchor(session)
        result = @client.submit(anchor, async: async)

        result.merge(
          session_id: session[:session_id],
          messages_hash: calculate_hash(session[:messages].to_json)
        )
      end

      # Anchor a relay operation from AuditLogger
      #
      # @param relay_data [Hash] Relay data with keys:
      #   - :relay_id [String] Unique relay identifier
      #   - :from [String] Sender's agent_id
      #   - :to [String] Recipient's agent_id
      #   - :blob_hash [String] Hash of encrypted blob
      #   - :message_type [String] Type of message relayed
      #   - :size_bytes [Integer] Size of the blob
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def anchor_relay(relay_data, async: false)
        validate_relay!(relay_data)

        anchor = build_relay_anchor(relay_data)
        @client.submit(anchor, async: async)
      end

      # Anchor a skill exchange event
      #
      # @param exchange_data [Hash] Exchange data with keys:
      #   - :skill_name [String] Name of the skill
      #   - :skill_hash [String] Content hash of the skill
      #   - :direction [Symbol] :sent or :received
      #   - :peer_id [String] Peer's instance_id
      #   - :provenance [Hash] Optional provenance info
      # @param async [Boolean] If true, queue for batch submission
      # @return [Hash] Submission result
      #
      def anchor_skill_exchange(exchange_data, async: false)
        anchor = build_skill_exchange_anchor(exchange_data)
        @client.submit(anchor, async: async)
      end

      # Get interaction history for a specific peer
      #
      # @param peer_id [String] Peer's instance_id
      # @param limit [Integer] Maximum number of results
      # @return [Array<Hash>] Interaction records
      #
      def peer_history(peer_id, limit: 50)
        all = @client.list(anchor_type: ANCHOR_TYPE, limit: limit * 2)
        all.select { |a| a[:participants]&.include?(peer_id) }.first(limit)
      end

      # Get all meeting anchors
      #
      # @param limit [Integer] Maximum number of results
      # @param since [String] Filter by timestamp (ISO8601)
      # @return [Array<Hash>] Meeting anchors
      #
      def list_meetings(limit: 100, since: nil)
        @client.list(anchor_type: ANCHOR_TYPE, limit: limit, since: since)
      end

      # Get session anchors only (exclude relays)
      #
      # @param limit [Integer] Maximum number of results
      # @return [Array<Hash>] Session anchors
      #
      def list_sessions(limit: 100)
        list_meetings(limit: limit * 2)
          .select { |a| a[:metadata]&.key?(:message_count) }
          .first(limit)
      end

      # Get skill exchange anchors only
      #
      # @param limit [Integer] Maximum number of results
      # @return [Array<Hash>] Skill exchange anchors
      #
      def list_skill_exchanges(limit: 100)
        list_meetings(limit: limit * 2)
          .select { |a| a[:metadata]&.key?(:skill_name) }
          .first(limit)
      end

      # Verify a session was recorded
      #
      # @param session_id [String] Session ID
      # @param session_data [Hash] Original session data (for hash verification)
      # @return [Hash] Verification result
      #
      def verify_session(session_id, session_data: nil)
        # Find by source_id
        sessions = list_sessions(limit: 1000)
        session = sessions.find { |s| s[:source_id] == session_id }

        return { exists: false, session_id: session_id } unless session

        result = {
          exists: true,
          session_id: session_id,
          anchor_hash: session[:anchor_hash],
          timestamp: session[:timestamp]
        }

        # If session_data provided, verify the hash matches
        if session_data
          expected_hash = calculate_hash(session_data.to_json)
          result[:data_hash_matches] = session[:data_hash] == expected_hash
        end

        result
      end

      # Get summary statistics for meeting anchors
      #
      # @return [Hash] Summary statistics
      #
      def meeting_stats
        all = list_meetings(limit: 10_000)

        sessions = all.select { |a| a[:metadata]&.key?(:message_count) }
        relays = all.select { |a| a[:metadata]&.key?(:size_bytes) }
        skill_exchanges = all.select { |a| a[:metadata]&.key?(:skill_name) }

        unique_peers = all.flat_map { |a| a[:participants] || [] }.uniq

        {
          total_anchors: all.size,
          sessions: sessions.size,
          relays: relays.size,
          skill_exchanges: skill_exchanges.size,
          unique_peers: unique_peers.size,
          total_messages: sessions.sum { |s| s.dig(:metadata, :message_count) || 0 },
          total_bytes_relayed: relays.sum { |r| r.dig(:metadata, :size_bytes) || 0 }
        }
      end

      private

      def validate_session!(session)
        required = %i[session_id peer_id messages]
        missing = required.reject { |k| session.key?(k) }

        return if missing.empty?

        raise ArgumentError, "Missing required session fields: #{missing.join(', ')}"
      end

      def validate_relay!(relay_data)
        required = %i[relay_id from to blob_hash]
        missing = required.reject { |k| relay_data.key?(k) }

        return if missing.empty?

        raise ArgumentError, "Missing required relay fields: #{missing.join(', ')}"
      end

      def build_session_anchor(session)
        HestiaChain::Core::Anchor.new(
          anchor_type: ANCHOR_TYPE,
          source_id: session[:session_id],
          data_hash: calculate_hash(session.to_json),
          participants: [session[:peer_id]].compact,
          metadata: {
            message_count: session[:messages]&.length || 0,
            interaction_types: extract_interaction_types(session[:messages]),
            started_at: session[:started_at],
            ended_at: session[:ended_at] || Time.now.utc.iso8601,
            duration_seconds: calculate_duration(session)
          }.compact
        )
      end

      def build_relay_anchor(relay_data)
        HestiaChain::Core::Anchor.new(
          anchor_type: ANCHOR_TYPE,
          source_id: relay_data[:relay_id],
          data_hash: relay_data[:blob_hash],
          participants: [relay_data[:from], relay_data[:to]].compact,
          metadata: {
            relay_type: 'message',
            message_type: relay_data[:message_type],
            size_bytes: relay_data[:size_bytes],
            relayed_at: Time.now.utc.iso8601
          }.compact
        )
      end

      def build_skill_exchange_anchor(exchange_data)
        HestiaChain::Core::Anchor.new(
          anchor_type: ANCHOR_TYPE,
          source_id: "skill_#{exchange_data[:skill_name]}_#{Time.now.to_i}",
          data_hash: exchange_data[:skill_hash],
          participants: [exchange_data[:peer_id]].compact,
          metadata: {
            skill_name: exchange_data[:skill_name],
            direction: exchange_data[:direction].to_s,
            provenance: exchange_data[:provenance],
            exchanged_at: Time.now.utc.iso8601
          }.compact
        )
      end

      def extract_interaction_types(messages)
        return [] unless messages.is_a?(Array)

        messages.map { |m| m[:type] || m['type'] }.compact.uniq
      end

      def calculate_duration(session)
        return nil unless session[:started_at] && session[:ended_at]

        start_time = Time.parse(session[:started_at])
        end_time = Time.parse(session[:ended_at])
        (end_time - start_time).to_i
      rescue ArgumentError
        nil
      end
    end
  end
end
