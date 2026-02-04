# frozen_string_literal: true

require 'spec_helper'
require 'digest'

RSpec.describe HestiaChain::Core::Anchor do
  let(:valid_hash) { Digest::SHA256.hexdigest('test data') }
  let(:valid_params) do
    {
      anchor_type: 'meeting',
      source_id: 'session_001',
      data_hash: valid_hash
    }
  end

  describe '#initialize' do
    it 'creates an anchor with required parameters' do
      anchor = described_class.new(**valid_params)

      expect(anchor.anchor_type).to eq('meeting')
      expect(anchor.source_id).to eq('session_001')
      expect(anchor.data_hash).to eq(valid_hash)
    end

    it 'creates an anchor with all parameters' do
      anchor = described_class.new(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data_hash: valid_hash,
        participants: %w[agent_a agent_b],
        metadata: { message_count: 42 },
        timestamp: '2026-02-03T10:00:00Z',
        previous_anchor_ref: 'prev_hash_123'
      )

      expect(anchor.participants).to eq(%w[agent_a agent_b])
      expect(anchor.metadata).to eq({ message_count: 42 })
      expect(anchor.timestamp).to eq('2026-02-03T10:00:00Z')
      expect(anchor.previous_anchor_ref).to eq('prev_hash_123')
    end

    it 'accepts standard anchor types' do
      HestiaChain::Core::Anchor::STANDARD_TYPES.each do |type|
        anchor = described_class.new(
          anchor_type: type,
          source_id: 'test',
          data_hash: valid_hash
        )
        expect(anchor.anchor_type).to eq(type)
      end
    end

    it 'accepts custom anchor types with custom. prefix' do
      anchor = described_class.new(
        anchor_type: 'custom.my_app.event',
        source_id: 'test',
        data_hash: valid_hash
      )
      expect(anchor.anchor_type).to eq('custom.my_app.event')
    end

    it 'raises error for invalid anchor type' do
      expect do
        described_class.new(
          anchor_type: 'invalid_type',
          source_id: 'test',
          data_hash: valid_hash
        )
      end.to raise_error(ArgumentError, /Invalid anchor_type/)
    end

    it 'raises error for invalid data hash format' do
      expect do
        described_class.new(
          anchor_type: 'meeting',
          source_id: 'test',
          data_hash: 'not_a_valid_hash'
        )
      end.to raise_error(ArgumentError, /Invalid data_hash format/)
    end

    it 'raises error for empty source_id' do
      expect do
        described_class.new(
          anchor_type: 'meeting',
          source_id: '',
          data_hash: valid_hash
        )
      end.to raise_error(ArgumentError, /source_id cannot be empty/)
    end

    it 'normalizes data hash with 0x prefix' do
      anchor = described_class.new(
        anchor_type: 'meeting',
        source_id: 'test',
        data_hash: "0x#{valid_hash}"
      )
      expect(anchor.data_hash).to eq(valid_hash)
    end

    it 'sets default timestamp if not provided' do
      anchor = described_class.new(**valid_params)
      expect(anchor.timestamp).not_to be_nil
      expect { Time.parse(anchor.timestamp) }.not_to raise_error
    end

    it 'sets empty arrays/hashes for optional params' do
      anchor = described_class.new(**valid_params)
      expect(anchor.participants).to eq([])
      expect(anchor.metadata).to eq({})
      expect(anchor.previous_anchor_ref).to be_nil
    end
  end

  describe '#anchor_hash' do
    it 'generates a SHA256 hash' do
      anchor = described_class.new(**valid_params)
      expect(anchor.anchor_hash).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'generates consistent hash for same data' do
      anchor1 = described_class.new(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data_hash: valid_hash,
        timestamp: '2026-02-03T10:00:00Z'
      )
      anchor2 = described_class.new(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data_hash: valid_hash,
        timestamp: '2026-02-03T10:00:00Z'
      )

      expect(anchor1.anchor_hash).to eq(anchor2.anchor_hash)
    end

    it 'generates different hash for different data' do
      anchor1 = described_class.new(**valid_params, timestamp: '2026-02-03T10:00:00Z')
      anchor2 = described_class.new(**valid_params, timestamp: '2026-02-03T11:00:00Z')

      expect(anchor1.anchor_hash).not_to eq(anchor2.anchor_hash)
    end

    it 'caches the hash' do
      anchor = described_class.new(**valid_params)
      hash1 = anchor.anchor_hash
      hash2 = anchor.anchor_hash
      expect(hash1).to equal(hash2) # Same object
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      anchor = described_class.new(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data_hash: valid_hash,
        participants: ['agent_a'],
        metadata: { count: 1 },
        timestamp: '2026-02-03T10:00:00Z'
      )

      hash = anchor.to_h

      expect(hash[:anchor_type]).to eq('meeting')
      expect(hash[:source_id]).to eq('session_001')
      expect(hash[:data_hash]).to eq(valid_hash)
      expect(hash[:participants]).to eq(['agent_a'])
      expect(hash[:metadata]).to eq({ count: 1 })
      expect(hash[:timestamp]).to eq('2026-02-03T10:00:00Z')
      expect(hash[:anchor_hash]).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'excludes nil values' do
      anchor = described_class.new(**valid_params)
      hash = anchor.to_h

      expect(hash).not_to have_key(:previous_anchor_ref)
    end
  end

  describe '#to_json' do
    it 'returns valid JSON' do
      anchor = described_class.new(**valid_params)
      json = anchor.to_json

      expect { JSON.parse(json) }.not_to raise_error
    end
  end

  describe '.from_h' do
    it 'creates an anchor from a hash' do
      original = described_class.new(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data_hash: valid_hash,
        participants: ['agent_a'],
        timestamp: '2026-02-03T10:00:00Z'
      )

      restored = described_class.from_h(original.to_h)

      expect(restored.anchor_type).to eq(original.anchor_type)
      expect(restored.source_id).to eq(original.source_id)
      expect(restored.data_hash).to eq(original.data_hash)
      expect(restored.anchor_hash).to eq(original.anchor_hash)
    end

    it 'handles string keys' do
      hash = {
        'anchor_type' => 'meeting',
        'source_id' => 'test',
        'data_hash' => valid_hash
      }

      anchor = described_class.from_h(hash)
      expect(anchor.anchor_type).to eq('meeting')
    end
  end

  describe '#valid?' do
    it 'returns true for valid anchor' do
      anchor = described_class.new(**valid_params)
      expect(anchor.valid?).to be true
    end
  end

  describe '#==' do
    it 'returns true for anchors with same hash' do
      anchor1 = described_class.new(**valid_params, timestamp: '2026-02-03T10:00:00Z')
      anchor2 = described_class.new(**valid_params, timestamp: '2026-02-03T10:00:00Z')

      expect(anchor1).to eq(anchor2)
    end

    it 'returns false for different anchors' do
      anchor1 = described_class.new(**valid_params, timestamp: '2026-02-03T10:00:00Z')
      anchor2 = described_class.new(**valid_params, timestamp: '2026-02-03T11:00:00Z')

      expect(anchor1).not_to eq(anchor2)
    end

    it 'returns false for non-Anchor objects' do
      anchor = described_class.new(**valid_params)
      expect(anchor).not_to eq('not an anchor')
    end
  end

  describe '#inspect' do
    it 'returns a readable string' do
      anchor = described_class.new(**valid_params)
      inspect = anchor.inspect

      expect(inspect).to include('HestiaChain::Anchor')
      expect(inspect).to include('type=meeting')
      expect(inspect).to include('source=session_001')
    end
  end
end
