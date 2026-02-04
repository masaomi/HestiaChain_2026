#!/usr/bin/env ruby
# frozen_string_literal: true

# Meeting Protocol Integration Example
#
# This example demonstrates how to integrate HestiaChain with the
# Meeting Protocol (MMP) for recording agent interaction witnesses.
#
# Run: ruby examples/meeting_protocol_integration.rb

require_relative '../lib/hestia_chain'
require 'digest'
require 'json'
require 'securerandom'

puts '=' * 60
puts 'HestiaChain + Meeting Protocol Integration Example'
puts '=' * 60
puts

# Simulated Meeting Protocol session data
# In real usage, this would come from the InteractionLog
def simulate_session
  {
    session_id: "session_#{SecureRandom.hex(6)}",
    peer_id: "agent_#{SecureRandom.hex(4)}",
    started_at: (Time.now - 300).utc.iso8601,
    ended_at: Time.now.utc.iso8601,
    messages: [
      { type: 'introduce_sent', timestamp: (Time.now - 290).utc.iso8601 },
      { type: 'introduce_received', timestamp: (Time.now - 285).utc.iso8601 },
      { type: 'skill_offered', timestamp: (Time.now - 200).utc.iso8601 },
      { type: 'offer_accepted', timestamp: (Time.now - 180).utc.iso8601 },
      { type: 'skill_transferred', timestamp: (Time.now - 100).utc.iso8601 },
      { type: 'meeting_ended', timestamp: Time.now.utc.iso8601 }
    ]
  }
end

# Meeting Protocol Integration class
# This would typically live in lib/hestia_chain/integrations/meeting_protocol.rb
class MeetingProtocolIntegration
  def initialize(hestia_client)
    @client = hestia_client
  end

  # Anchor a completed session
  def anchor_session(session)
    # Calculate session hash (what gets recorded on-chain)
    session_json = session.to_json
    data_hash = Digest::SHA256.hexdigest(session_json)

    # Create the anchor
    anchor = HestiaChain::Core::Anchor.new(
      anchor_type: 'meeting',
      source_id: session[:session_id],
      data_hash: data_hash,
      participants: [session[:peer_id]],
      metadata: {
        message_count: session[:messages].length,
        interaction_types: session[:messages].map { |m| m[:type] }.uniq,
        started_at: session[:started_at],
        ended_at: session[:ended_at],
        duration_seconds: Time.parse(session[:ended_at]) - Time.parse(session[:started_at])
      }
    )

    # Submit to HestiaChain
    result = @client.submit(anchor)

    {
      result: result,
      anchor: anchor,
      session_hash: data_hash
    }
  end

  # Anchor a relay operation (from AuditLogger)
  def anchor_relay(relay_data)
    anchor = HestiaChain::Core::Anchor.new(
      anchor_type: 'meeting',
      source_id: relay_data[:relay_id],
      data_hash: relay_data[:blob_hash],
      participants: [relay_data[:from], relay_data[:to]].compact,
      metadata: {
        message_type: relay_data[:message_type],
        size_bytes: relay_data[:size_bytes],
        relayed_at: Time.now.utc.iso8601
      }
    )

    @client.submit(anchor)
  end

  # Get interaction history for a peer
  def peer_history(peer_id, limit: 20)
    all = @client.list(anchor_type: 'meeting', limit: limit * 2)
    all.select { |a| a[:participants]&.include?(peer_id) }.first(limit)
  end
end

# Demo
puts '1. Initializing HestiaChain client...'
client = HestiaChain.client
integration = MeetingProtocolIntegration.new(client)
puts "   Client ready (backend: #{client.backend_type})"
puts

# Simulate multiple sessions
puts '2. Simulating meeting sessions...'
sessions = 3.times.map { simulate_session }
sessions.each do |session|
  puts "   Session: #{session[:session_id]}"
  puts "     Peer: #{session[:peer_id]}"
  puts "     Messages: #{session[:messages].length}"
end
puts

# Anchor each session
puts '3. Anchoring sessions to HestiaChain...'
anchored = sessions.map do |session|
  result = integration.anchor_session(session)
  puts "   Anchored: #{session[:session_id]}"
  puts "     Anchor Hash: #{result[:anchor]&.anchor_hash&.slice(0, 32)}..."
  puts "     Status: #{result[:result][:status]}"
  result
end
puts

# Simulate relay operations
puts '4. Anchoring relay operations...'
3.times do |i|
  relay_data = {
    relay_id: "relay_#{SecureRandom.hex(4)}",
    from: "agent_#{SecureRandom.hex(3)}",
    to: "agent_#{SecureRandom.hex(3)}",
    blob_hash: Digest::SHA256.hexdigest("encrypted_message_#{i}"),
    message_type: %w[skill_content introduce offer_skill][i],
    size_bytes: rand(1000..10_000)
  }

  result = integration.anchor_relay(relay_data)
  puts "   Relay #{relay_data[:relay_id]}: #{result[:status]}"
end
puts

# Query history
puts '5. Querying meeting history...'
all_meetings = client.list(anchor_type: 'meeting')
puts "   Total meeting anchors: #{all_meetings.size}"

if sessions.first
  peer = sessions.first[:peer_id]
  peer_meetings = integration.peer_history(peer)
  puts "   Sessions with #{peer}: #{peer_meetings.size}"
end
puts

# Verify a session anchor
puts '6. Verifying session anchor...'
if anchored.first
  hash = anchored.first[:anchor].anchor_hash
  verification = client.verify(hash)
  puts "   Anchor: #{hash[0, 32]}..."
  puts "   Exists: #{verification[:exists]}"
  puts "   Type: #{verification[:anchor_type]}"
end
puts

# Show statistics
puts '7. Statistics...'
stats = client.stats[:backend]
puts "   Total anchors: #{stats[:total_anchors]}"
puts "   By type: #{stats[:anchors_by_type]}"
puts

puts '=' * 60
puts 'Meeting Protocol integration example completed!'
puts
puts 'Key Points:'
puts '- Sessions are hashed, only the hash is recorded (privacy)'
puts '- Participants are recorded for later reconstruction'
puts '- Metadata enables filtering and analysis'
puts '- Multiple agents cooperating can reconstruct history'
puts '=' * 60
