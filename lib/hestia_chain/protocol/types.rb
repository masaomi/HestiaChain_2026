# frozen_string_literal: true

module HestiaChain
  module Protocol
    # Protocol-specific constants and types for the philosophical protocol layer.
    #
    # This module defines the anchor types and philosophy types used by
    # the Exchange Philosophy system. It is opt-in and only loaded when
    # `require 'hestia_chain/protocol'` is explicitly called.
    #
    # Design Philosophy (Beyond DAO):
    # > "How can we remain connected without deciding the same thing?"
    #
    # The protocol layer enables agents to:
    # - Declare their exchange philosophy (not requiring consensus)
    # - Record observations of interactions (without enforcing judgments)
    # - Allow multiple interpretations to coexist
    #
    module Types
      # Anchor types specific to the philosophical protocol layer
      PROTOCOL_ANCHOR_TYPES = %w[
        philosophy_declaration
        observation_log
      ].freeze

      # Types of philosophy that can be declared
      #
      # - exchange: Philosophy about skill exchange and sharing
      # - interaction: Philosophy about general inter-agent interaction
      # - fadeout: Philosophy about disengagement and relationship decay
      #
      PHILOSOPHY_TYPES = %w[
        exchange
        interaction
        fadeout
      ].freeze

      # Types of observations that can be recorded
      #
      # - initiated: An interaction was initiated
      # - completed: An interaction completed (without judgment of success/failure)
      # - faded: A relationship naturally faded out
      # - observed: A general observation was made
      #
      OBSERVATION_TYPES = %w[
        initiated
        completed
        faded
        observed
      ].freeze

      # Predefined compatibility tags for exchange philosophies
      #
      # Agents can use these tags to indicate what kinds of exchange
      # philosophies they are compatible with. This is declarative only;
      # actual compatibility is determined by each agent locally.
      #
      COMPATIBILITY_TAGS = %w[
        cooperative
        competitive
        observational
        experimental
        conservative
        adaptive
      ].freeze
    end
  end
end
