# frozen_string_literal: true

# HestiaChain Philosophy Protocol Layer
#
# This is an OPT-IN module that provides the philosophical protocol layer
# for HestiaChain. It is NOT loaded by default when you require 'hestia_chain'.
#
# To use the protocol layer, explicitly require this file:
#
#   require 'hestia_chain'
#   require 'hestia_chain/protocol'
#
# Design Philosophy (Beyond DAO):
#
#   > "How can we remain connected without deciding the same thing?"
#
# The protocol layer enables:
# - Philosophy declarations (without requiring consensus)
# - Observation logging (without enforcing judgments)
# - Coexistence of multiple interpretations
# - Natural fade-out as a legitimate outcome
#
# Key Concepts:
#
# - PhilosophyDeclaration: Declare your exchange philosophy (observable, not enforceable)
# - ObservationLog: Record observations of interactions (subjective, not universal)
#
# @example Basic usage
#   require 'hestia_chain'
#   require 'hestia_chain/protocol'
#
#   client = HestiaChain.client
#
#   # Declare a philosophy
#   declaration = HestiaChain::Protocol::PhilosophyDeclaration.new(
#     agent_id: 'my_agent',
#     philosophy_type: 'exchange',
#     philosophy_hash: Digest::SHA256.hexdigest(my_philosophy.to_json),
#     compatible_with: ['cooperative']
#   )
#   client.submit(declaration.to_anchor)
#
#   # Record an observation
#   observation = HestiaChain::Protocol::ObservationLog.new(
#     observer_id: 'my_agent',
#     observed_id: 'other_agent',
#     interaction_hash: Digest::SHA256.hexdigest(interaction.to_json),
#     observation_type: 'completed'
#   )
#   client.submit(observation.to_anchor)
#
# @see HestiaChain::Protocol::Types Protocol-specific constants
# @see HestiaChain::Protocol::PhilosophyDeclaration Philosophy declaration class
# @see HestiaChain::Protocol::ObservationLog Observation log class
#
require_relative 'protocol/types'
require_relative 'protocol/philosophy_declaration'
require_relative 'protocol/observation_log'

module HestiaChain
  module Protocol
    class << self
      # Get the version of the protocol layer
      #
      # @return [String] Protocol version
      #
      def version
        '0.1.0'
      end

      # Check if a philosophy type is valid
      #
      # @param type [String] Philosophy type to check
      # @return [Boolean] True if valid
      #
      def valid_philosophy_type?(type)
        Types::PHILOSOPHY_TYPES.include?(type.to_s) || type.to_s.start_with?('custom.')
      end

      # Check if an observation type is valid
      #
      # @param type [String] Observation type to check
      # @return [Boolean] True if valid
      #
      def valid_observation_type?(type)
        Types::OBSERVATION_TYPES.include?(type.to_s) || type.to_s.start_with?('custom.')
      end

      # Check if a compatibility tag is predefined
      #
      # @param tag [String] Compatibility tag to check
      # @return [Boolean] True if predefined (custom tags are always allowed)
      #
      def predefined_compatibility_tag?(tag)
        Types::COMPATIBILITY_TAGS.include?(tag.to_s)
      end
    end
  end
end
