# frozen_string_literal: true

require_relative 'hestia_chain/version'
require_relative 'hestia_chain/core/anchor'
require_relative 'hestia_chain/core/config'
require_relative 'hestia_chain/core/client'
require_relative 'hestia_chain/core/batch_processor'
require_relative 'hestia_chain/backend/base'

# HestiaChain - Generic Private to Public Blockchain Migration Module
#
# HestiaChain provides a pluggable backend system for recording proof-of-existence
# anchors, enabling smooth migration from private storage to public blockchains.
#
# Design Philosophy:
# > "History is not replayable, but reconstructible through cooperation."
#
# HestiaChain is designed as a "witness/anchor" module that records only hashes
# (proof of existence), never the actual data. This ensures privacy while
# enabling auditability through cooperation between participants.
#
# ## Stages
#
# - **Stage 0 (InMemory)**: Development and testing
# - **Stage 1 (Private)**: JSON file-based storage
# - **Stage 2 (Public Testnet)**: Ethereum testnet (e.g., Base Sepolia)
# - **Stage 3 (Public Mainnet)**: Ethereum mainnet (e.g., Base)
#
# ## Quick Start
#
#     require 'hestia_chain'
#
#     # Create a client (uses in_memory backend by default)
#     client = HestiaChain.client
#
#     # Create and submit an anchor
#     result = client.anchor(
#       anchor_type: 'research_data',
#       source_id: 'experiment_001',
#       data: { result: 'success', value: 42 }
#     )
#
#     puts result[:anchor_hash]
#
#     # Verify the anchor
#     verification = client.verify(result[:anchor_hash])
#     puts "Exists: #{verification[:exists]}"
#
# ## Configuration
#
# HestiaChain looks for configuration in these locations:
#
# 1. `config/hestia_chain.yml`
# 2. `hestia_chain.yml`
# 3. `~/.hestia_chain.yml`
#
# Example configuration:
#
#     development:
#       enabled: true
#       backend: in_memory
#
#     production:
#       enabled: true
#       backend: public_mainnet
#       batching:
#         enabled: true
#         interval_seconds: 3600
#         max_batch_size: 100
#       public_mainnet:
#         chain: base
#         rpc_url: <%= ENV['HESTIA_RPC_URL'] %>
#         contract_address: <%= ENV['HESTIA_CONTRACT_ADDRESS'] %>
#
# ## Use Cases
#
# - **Meeting Protocol**: Record agent interaction witnesses
# - **GenomicsChain**: Anchor NFT and data provenance
# - **Research Data**: Prove existence of datasets
# - **Agreements**: Record contract signatures
# - **Audit Logs**: Immutable audit trails
#
# @see HestiaChain::Core::Client Main client class
# @see HestiaChain::Core::Anchor Anchor data structure
# @see HestiaChain::Core::Config Configuration management
#
module HestiaChain
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class BackendError < Error; end
  class ValidationError < Error; end

  class << self
    # Create a new client with default or custom configuration
    #
    # @param config [Hash, Core::Config, nil] Configuration
    # @return [Core::Client] Client instance
    #
    # @example Default client
    #   client = HestiaChain.client
    #
    # @example With custom config
    #   client = HestiaChain.client(backend: 'private')
    #
    def client(config = nil)
      Core::Client.new(config: config)
    end

    # Create a new anchor
    #
    # @param anchor_type [String] Anchor type
    # @param source_id [String] Source identifier
    # @param data_hash [String] SHA256 hash of the data
    # @param options [Hash] Additional options
    # @return [Core::Anchor] New anchor instance
    #
    def anchor(anchor_type:, source_id:, data_hash:, **options)
      Core::Anchor.new(
        anchor_type: anchor_type,
        source_id: source_id,
        data_hash: data_hash,
        **options
      )
    end

    # Load configuration
    #
    # @param path [String, nil] Path to config file
    # @param environment [String, nil] Environment name
    # @return [Core::Config] Configuration instance
    #
    def config(path: nil, environment: nil)
      Core::Config.load(path: path, environment: environment)
    end

    # Get the library version
    #
    # @return [String] Version string
    #
    def version
      VERSION
    end
  end
end
