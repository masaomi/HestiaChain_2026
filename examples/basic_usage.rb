#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic HestiaChain Usage Example
#
# This example demonstrates the core functionality of HestiaChain
# using the in-memory backend (suitable for development and testing).
#
# Run: ruby examples/basic_usage.rb

require_relative '../lib/hestia_chain'
require 'digest'

puts '=' * 60
puts 'HestiaChain Basic Usage Example'
puts '=' * 60
puts

# 1. Create a client (uses in_memory backend by default)
puts '1. Creating HestiaChain client...'
client = HestiaChain.client
puts "   Backend: #{client.backend_type}"
puts "   Enabled: #{client.status[:enabled]}"
puts

# 2. Create an anchor using the convenience method
puts '2. Creating and submitting an anchor (convenience method)...'
result = client.anchor(
  anchor_type: 'research',
  source_id: 'experiment_001',
  data: { result: 'success', value: 42, measurements: [1.2, 3.4, 5.6] },
  participants: ['researcher_a', 'researcher_b'],
  metadata: { institution: 'UZH', project: 'GenomicsChain' }
)
puts "   Status: #{result[:status]}"
puts "   Anchor Hash: #{result[:anchor_hash]}"
puts

# 3. Verify the anchor exists
puts '3. Verifying the anchor...'
verification = client.verify(result[:anchor_hash])
puts "   Exists: #{verification[:exists]}"
puts "   Type: #{verification[:anchor_type]}"
puts "   Timestamp: #{verification[:timestamp]}"
puts

# 4. Retrieve the full anchor data
puts '4. Retrieving full anchor data...'
anchor_data = client.get(result[:anchor_hash])
puts "   Source ID: #{anchor_data[:source_id]}"
puts "   Participants: #{anchor_data[:participants].join(', ')}"
puts "   Metadata: #{anchor_data[:metadata]}"
puts

# 5. Create multiple anchors manually
puts '5. Creating multiple anchors manually...'
anchors = 3.times.map do |i|
  HestiaChain::Core::Anchor.new(
    anchor_type: 'audit',
    source_id: "log_entry_#{i + 1}",
    data_hash: Digest::SHA256.hexdigest("Log entry #{i + 1}: Action completed"),
    metadata: { severity: %w[info warning error][i], timestamp: Time.now.iso8601 }
  )
end

anchors.each do |anchor|
  client.submit(anchor)
  puts "   Submitted: #{anchor.source_id} (#{anchor.anchor_hash[0, 16]}...)"
end
puts

# 6. List all anchors
puts '6. Listing all anchors...'
all_anchors = client.list(limit: 10)
puts "   Total: #{all_anchors.size} anchors"
all_anchors.each do |a|
  puts "   - [#{a[:anchor_type]}] #{a[:source_id]}"
end
puts

# 7. Filter anchors by type
puts '7. Filtering anchors by type...'
audit_anchors = client.list(anchor_type: 'audit')
puts "   Audit anchors: #{audit_anchors.size}"
research_anchors = client.list(anchor_type: 'research')
puts "   Research anchors: #{research_anchors.size}"
puts

# 8. Check client statistics
puts '8. Client statistics...'
stats = client.stats
puts "   Backend: #{stats[:backend][:backend_type]}"
puts "   Total anchors: #{stats[:backend][:total_anchors]}"
puts "   By type: #{stats[:backend][:anchors_by_type]}"
puts

puts '=' * 60
puts 'Example completed successfully!'
puts '=' * 60
