# frozen_string_literal: true

module HestiaChain
  module Integrations
    # Base class for HestiaChain integrations.
    #
    # Integrations provide application-specific adapters for using HestiaChain.
    # They handle the translation between application-specific data structures
    # and HestiaChain anchors.
    #
    # @abstract Subclass and implement application-specific methods
    #
    class Base
      attr_reader :client

      # Create a new integration
      #
      # @param client [HestiaChain::Core::Client] HestiaChain client
      #
      def initialize(client:)
        @client = client
      end

      # Check if the integration is ready
      #
      # @return [Boolean] True if client is ready
      #
      def ready?
        @client.status[:backend_ready]
      end

      # Get integration statistics
      #
      # @return [Hash] Statistics
      #
      def stats
        {
          integration: self.class.name,
          client: @client.stats
        }
      end

      protected

      # Build an anchor from application data
      #
      # @param anchor_type [String] Anchor type
      # @param source_id [String] Source identifier
      # @param data [Object] Data to hash
      # @param options [Hash] Additional options
      # @return [HestiaChain::Core::Anchor] New anchor
      #
      def build_anchor(anchor_type:, source_id:, data:, **options)
        data_hash = calculate_hash(data)

        HestiaChain::Core::Anchor.new(
          anchor_type: anchor_type,
          source_id: source_id,
          data_hash: data_hash,
          **options
        )
      end

      # Calculate SHA256 hash of data
      #
      # @param data [Object] Data to hash
      # @return [String] SHA256 hex digest
      #
      def calculate_hash(data)
        content = case data
                  when String then data
                  when Hash then data.to_json
                  else data.to_s
                  end
        Digest::SHA256.hexdigest(content)
      end
    end
  end
end
