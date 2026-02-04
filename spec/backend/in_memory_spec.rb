# frozen_string_literal: true

require 'spec_helper'
require 'digest'

RSpec.describe HestiaChain::Backend::InMemory do
  let(:config) { HestiaChain::Core::Config.new(backend: 'in_memory') }
  let(:backend) { described_class.new(config) }
  let(:valid_hash) { Digest::SHA256.hexdigest('test data') }
  let(:anchor) do
    HestiaChain::Core::Anchor.new(
      anchor_type: 'meeting',
      source_id: 'test_001',
      data_hash: valid_hash,
      participants: %w[agent_a agent_b],
      metadata: { count: 42 }
    )
  end

  describe '#initialize' do
    it 'creates an empty backend' do
      expect(backend.count).to eq(0)
    end
  end

  describe '#submit_anchor' do
    it 'submits an anchor successfully' do
      result = backend.submit_anchor(anchor)

      expect(result[:status]).to eq('submitted')
      expect(result[:anchor_hash]).to eq(anchor.anchor_hash)
      expect(result[:backend]).to eq('in_memory')
    end

    it 'returns exists status for duplicate anchor' do
      backend.submit_anchor(anchor)
      result = backend.submit_anchor(anchor)

      expect(result[:status]).to eq('exists')
      expect(result[:message]).to include('already exists')
    end

    it 'raises error for non-Anchor objects' do
      expect { backend.submit_anchor('not an anchor') }.to raise_error(ArgumentError)
    end

    it 'stores all anchor fields' do
      backend.submit_anchor(anchor)
      stored = backend.get_anchor(anchor.anchor_hash)

      expect(stored[:anchor_type]).to eq('meeting')
      expect(stored[:source_id]).to eq('test_001')
      expect(stored[:participants]).to eq(%w[agent_a agent_b])
      expect(stored[:metadata]).to eq({ count: 42 })
    end
  end

  describe '#submit_anchors' do
    it 'submits multiple anchors' do
      anchors = 3.times.map do |i|
        HestiaChain::Core::Anchor.new(
          anchor_type: 'generic',
          source_id: "test_#{i}",
          data_hash: Digest::SHA256.hexdigest("data_#{i}")
        )
      end

      result = backend.submit_anchors(anchors)

      expect(result[:status]).to eq('submitted')
      expect(result[:count]).to eq(3)
      expect(result[:anchor_hashes].size).to eq(3)
    end
  end

  describe '#verify_anchor' do
    it 'verifies existing anchor' do
      backend.submit_anchor(anchor)
      result = backend.verify_anchor(anchor.anchor_hash)

      expect(result[:exists]).to be true
      expect(result[:anchor_type]).to eq('meeting')
      expect(result[:timestamp]).not_to be_nil
    end

    it 'returns false for non-existing anchor' do
      result = backend.verify_anchor('nonexistent')

      expect(result[:exists]).to be false
    end
  end

  describe '#get_anchor' do
    it 'retrieves existing anchor' do
      backend.submit_anchor(anchor)
      result = backend.get_anchor(anchor.anchor_hash)

      expect(result[:anchor_hash]).to eq(anchor.anchor_hash)
      expect(result[:data_hash]).to eq(valid_hash)
    end

    it 'returns nil for non-existing anchor' do
      result = backend.get_anchor('nonexistent')
      expect(result).to be_nil
    end

    it 'returns a copy (not the original)' do
      backend.submit_anchor(anchor)
      result1 = backend.get_anchor(anchor.anchor_hash)
      result2 = backend.get_anchor(anchor.anchor_hash)

      expect(result1).not_to equal(result2)
    end
  end

  describe '#list_anchors' do
    before do
      5.times do |i|
        a = HestiaChain::Core::Anchor.new(
          anchor_type: i.even? ? 'meeting' : 'generic',
          source_id: "test_#{i}",
          data_hash: Digest::SHA256.hexdigest("data_#{i}"),
          timestamp: "2026-02-0#{i + 1}T10:00:00Z"
        )
        backend.submit_anchor(a)
      end
    end

    it 'lists all anchors' do
      result = backend.list_anchors
      expect(result.size).to eq(5)
    end

    it 'limits results' do
      result = backend.list_anchors(limit: 3)
      expect(result.size).to eq(3)
    end

    it 'filters by anchor_type' do
      result = backend.list_anchors(anchor_type: 'meeting')
      expect(result.size).to eq(3)
      expect(result.all? { |a| a[:anchor_type] == 'meeting' }).to be true
    end

    it 'filters by timestamp' do
      result = backend.list_anchors(since: '2026-02-03T00:00:00Z')
      expect(result.size).to eq(3)
    end

    it 'returns newest first' do
      result = backend.list_anchors
      timestamps = result.map { |a| a[:timestamp] }
      expect(timestamps).to eq(timestamps.sort.reverse)
    end
  end

  describe '#backend_type' do
    it 'returns :in_memory' do
      expect(backend.backend_type).to eq(:in_memory)
    end
  end

  describe '#ready?' do
    it 'returns true' do
      expect(backend.ready?).to be true
    end
  end

  describe '#stats' do
    it 'returns statistics' do
      backend.submit_anchor(anchor)
      stats = backend.stats

      expect(stats[:backend_type]).to eq(:in_memory)
      expect(stats[:ready]).to be true
      expect(stats[:total_anchors]).to eq(1)
      expect(stats[:anchors_by_type]).to eq({ 'meeting' => 1 })
    end
  end

  describe '#clear!' do
    it 'removes all anchors' do
      backend.submit_anchor(anchor)
      expect(backend.count).to eq(1)

      cleared = backend.clear!

      expect(cleared).to eq(1)
      expect(backend.count).to eq(0)
    end
  end

  describe '#count' do
    it 'returns the number of anchors' do
      expect(backend.count).to eq(0)

      backend.submit_anchor(anchor)
      expect(backend.count).to eq(1)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent submissions' do
      threads = 10.times.map do |i|
        Thread.new do
          a = HestiaChain::Core::Anchor.new(
            anchor_type: 'generic',
            source_id: "thread_#{i}",
            data_hash: Digest::SHA256.hexdigest("data_#{i}")
          )
          backend.submit_anchor(a)
        end
      end

      threads.each(&:join)
      expect(backend.count).to eq(10)
    end
  end
end
