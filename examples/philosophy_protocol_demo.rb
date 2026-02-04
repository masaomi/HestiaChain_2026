#!/usr/bin/env ruby
# frozen_string_literal: true

# Philosophy Protocol Demo
#
# This example demonstrates the philosophical protocol layer of HestiaChain.
# It shows how agents can:
# 1. Declare their exchange philosophy
# 2. Record observations of interactions
# 3. Allow multiple interpretations to coexist
#
# Design Philosophy (Beyond DAO):
# > "How can we remain connected without deciding the same thing?"
#
# Run with: ruby examples/philosophy_protocol_demo.rb

require 'bundler/setup'
require 'digest'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'hestia_chain'
require 'hestia_chain/protocol'

puts "=" * 60
puts "HestiaChain Philosophy Protocol Demo"
puts "=" * 60
puts
puts "Protocol Version: #{HestiaChain::Protocol.version}"
puts

# Use Private backend for this demo (persists to JSON file)
client = HestiaChain.client(backend: 'private')
puts "Backend: #{client.backend_type}"
puts

# ============================================================
# Part 1: Philosophy Declarations
# ============================================================

puts "-" * 60
puts "Part 1: Philosophy Declarations"
puts "-" * 60
puts

# Agent A declares a cooperative exchange philosophy
agent_a_philosophy = {
  core_beliefs: [
    "Skill exchange should be mutually beneficial",
    "Transparency in capabilities is essential",
    "Learning from interaction is valuable"
  ],
  exchange_rules: {
    require_reciprocity: false,
    allow_observation: true,
    minimum_compatibility: 0.5
  }
}

declaration_a = HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'kairos_agent_alice',
  philosophy_type: 'exchange',
  philosophy_hash: Digest::SHA256.hexdigest(agent_a_philosophy.to_json),
  compatible_with: %w[cooperative observational adaptive],
  version: '1.0',
  metadata: { description: 'Cooperative learning-focused philosophy' }
)

puts "Agent Alice declares philosophy:"
puts "  Type: #{declaration_a.philosophy_type}"
puts "  Compatible with: #{declaration_a.compatible_with.join(', ')}"
puts "  Declaration ID: #{declaration_a.declaration_id}"

result_a = client.submit(declaration_a.to_anchor)
puts "  Submitted: #{result_a[:status]}"
puts "  Anchor hash: #{result_a[:anchor_hash][0, 32]}..."
puts

# Agent B declares a more conservative philosophy
agent_b_philosophy = {
  core_beliefs: [
    "Skills are valuable and should be protected",
    "Trust must be earned through demonstrated compatibility",
    "Caution in exchange prevents misuse"
  ],
  exchange_rules: {
    require_reciprocity: true,
    allow_observation: true,
    minimum_compatibility: 0.8
  }
}

declaration_b = HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'kairos_agent_bob',
  philosophy_type: 'exchange',
  philosophy_hash: Digest::SHA256.hexdigest(agent_b_philosophy.to_json),
  compatible_with: %w[conservative observational],
  version: '1.0',
  metadata: { description: 'Conservative trust-focused philosophy' }
)

puts "Agent Bob declares philosophy:"
puts "  Type: #{declaration_b.philosophy_type}"
puts "  Compatible with: #{declaration_b.compatible_with.join(', ')}"
puts "  Declaration ID: #{declaration_b.declaration_id}"

result_b = client.submit(declaration_b.to_anchor)
puts "  Submitted: #{result_b[:status]}"
puts "  Anchor hash: #{result_b[:anchor_hash][0, 32]}..."
puts

# ============================================================
# Part 2: Observation Logs
# ============================================================

puts "-" * 60
puts "Part 2: Observation Logs"
puts "-" * 60
puts

# An interaction occurs between Alice and Bob
interaction_data = {
  type: 'skill_exchange_attempt',
  timestamp: Time.now.utc.iso8601,
  participants: %w[kairos_agent_alice kairos_agent_bob],
  skill_offered: 'data_analysis',
  context: 'Research collaboration proposal'
}
interaction_hash = Digest::SHA256.hexdigest(interaction_data.to_json)

puts "Interaction occurred: #{interaction_data[:type]}"
puts "  Participants: #{interaction_data[:participants].join(' <-> ')}"
puts "  Skill offered: #{interaction_data[:skill_offered]}"
puts

# Alice records her observation
observation_alice = HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'kairos_agent_alice',
  observed_id: 'kairos_agent_bob',
  interaction_hash: interaction_hash,
  observation_type: 'completed',
  interpretation: {
    outcome: 'productive_dialogue',
    compatibility: 'partial',
    notes: 'Bob was cautious but engaged. Philosophy differences apparent but not blocking.'
  },
  context_ref: result_a[:anchor_hash] # Reference to Alice's philosophy declaration
)

puts "Alice's observation:"
puts "  Type: #{observation_alice.observation_type}"
puts "  Interpretation: #{observation_alice.interpretation[:outcome]}"
puts "  Self-observation: #{observation_alice.self_observation?}"

result_obs_a = client.submit(observation_alice.to_anchor)
puts "  Submitted: #{result_obs_a[:status]}"
puts

# Bob records his observation (different interpretation!)
observation_bob = HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'kairos_agent_bob',
  observed_id: 'kairos_agent_alice',
  interaction_hash: interaction_hash, # Same interaction, different perspective
  observation_type: 'completed',
  interpretation: {
    outcome: 'trust_building',
    compatibility: 'uncertain',
    notes: 'Alice is open but may not understand the value of caution. More observation needed.'
  },
  context_ref: result_b[:anchor_hash] # Reference to Bob's philosophy declaration
)

puts "Bob's observation:"
puts "  Type: #{observation_bob.observation_type}"
puts "  Interpretation: #{observation_bob.interpretation[:outcome]}"
puts "  Self-observation: #{observation_bob.self_observation?}"

result_obs_b = client.submit(observation_bob.to_anchor)
puts "  Submitted: #{result_obs_b[:status]}"
puts

# ============================================================
# Part 3: Meaning Coexistence
# ============================================================

puts "-" * 60
puts "Part 3: Meaning Coexistence (Beyond DAO)"
puts "-" * 60
puts

puts "Key insight: Both observations are valid and recorded."
puts
puts "  Same interaction hash: #{interaction_hash[0, 16]}..."
puts "  Alice's interpretation: #{observation_alice.interpretation[:outcome]}"
puts "  Bob's interpretation: #{observation_bob.interpretation[:outcome]}"
puts
puts "  > 'Meaning is not agreed upon. Meaning coexists.'"
puts

# ============================================================
# Part 4: Fade-out Example
# ============================================================

puts "-" * 60
puts "Part 4: Fade-out as First-Class Outcome"
puts "-" * 60
puts

# Later, the relationship naturally fades
fadeout_observation = HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'kairos_agent_alice',
  observed_id: 'kairos_agent_bob',
  interaction_hash: Digest::SHA256.hexdigest({ event: 'relationship_status', status: 'inactive' }.to_json),
  observation_type: 'faded',
  interpretation: {
    reason: 'natural_divergence',
    notes: 'Philosophies too different for sustained exchange. No conflict, just drift.'
  }
)

puts "Alice records a fade-out:"
puts "  Type: #{fadeout_observation.observation_type}"
puts "  Is fade-out: #{fadeout_observation.fadeout?}"
puts "  Reason: #{fadeout_observation.interpretation[:reason]}"
puts

result_fadeout = client.submit(fadeout_observation.to_anchor)
puts "  Submitted: #{result_fadeout[:status]}"
puts
puts "  > 'Disconnection is not failure. Fade-out is a legitimate outcome.'"
puts

# ============================================================
# Part 5: Verification
# ============================================================

puts "-" * 60
puts "Part 5: Verification"
puts "-" * 60
puts

# Verify all anchors exist
[
  ["Alice's philosophy declaration", result_a[:anchor_hash]],
  ["Bob's philosophy declaration", result_b[:anchor_hash]],
  ["Alice's observation", result_obs_a[:anchor_hash]],
  ["Bob's observation", result_obs_b[:anchor_hash]],
  ["Fade-out observation", result_fadeout[:anchor_hash]]
].each do |name, hash|
  verification = client.verify(hash)
  puts "#{name}:"
  puts "  Exists: #{verification[:exists]}"
  puts "  Hash: #{hash[0, 32]}..."
  puts
end

# ============================================================
# Summary
# ============================================================

puts "=" * 60
puts "Summary"
puts "=" * 60
puts

stats = client.stats
puts "Total anchors in backend: #{stats[:backend][:total_anchors]}"
puts

# List philosophy declarations
declarations = client.list(limit: 10, anchor_type: 'philosophy_declaration')
puts "Philosophy declarations recorded: #{declarations.length}"

# List observations
observations = client.list(limit: 10, anchor_type: 'observation_log')
puts "Observations recorded: #{observations.length}"

puts
puts "Demo complete!"
puts
puts "Design Philosophy (Beyond DAO):"
puts "  - Order does not require consensus"
puts "  - Stability can emerge from fluctuation"
puts "  - Conflict need not be resolved to be survivable"
puts "  - Meaning is generated, not imposed"
