# frozen_string_literal: true

require 'spec_helper'
require 'digest'

RSpec.describe HestiaChain::Core::Client do
  let(:valid_hash) { Digest::SHA256.hexdigest('test data') }

  describe '#initialize' do
    it 'creates client with default config' do
      client = described_class.new
      expect(client.config).to be_a(HestiaChain::Core::Config)
      expect(client.backend).to be_a(HestiaChain::Backend::Base)
    end

    it 'creates client with hash config' do
      client = described_class.new(config: { backend: 'in_memory' })
      expect(client.backend_type).to eq(:in_memory)
    end

    it 'creates client with Config object' do
      config = HestiaChain::Core::Config.new(backend: 'in_memory')
      client = described_class.new(config: config)
      expect(client.config).to eq(config)
    end
  end

  describe '#submit' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }
    let(:anchor) do
      HestiaChain::Core::Anchor.new(
        anchor_type: 'meeting',
        source_id: 'test_001',
        data_hash: valid_hash
      )
    end

    it 'submits an anchor synchronously' do
      result = client.submit(anchor)

      expect(result[:status]).to eq('submitted')
      expect(result[:anchor_hash]).to eq(anchor.anchor_hash)
    end

    it 'returns disabled status when HestiaChain is disabled' do
      client = described_class.new(config: { enabled: false })
      result = client.submit(anchor)

      expect(result[:status]).to eq('disabled')
    end

    it 'raises error for non-Anchor objects' do
      expect { client.submit('not an anchor') }.to raise_error(ArgumentError)
    end
  end

  describe '#verify' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }
    let(:anchor) do
      HestiaChain::Core::Anchor.new(
        anchor_type: 'meeting',
        source_id: 'test_001',
        data_hash: valid_hash
      )
    end

    it 'verifies an existing anchor' do
      client.submit(anchor)
      result = client.verify(anchor.anchor_hash)

      expect(result[:exists]).to be true
      expect(result[:anchor_type]).to eq('meeting')
    end

    it 'returns false for non-existing anchor' do
      result = client.verify('nonexistent_hash')

      expect(result[:exists]).to be false
    end
  end

  describe '#get' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }
    let(:anchor) do
      HestiaChain::Core::Anchor.new(
        anchor_type: 'meeting',
        source_id: 'test_001',
        data_hash: valid_hash,
        participants: ['agent_a']
      )
    end

    it 'retrieves an existing anchor' do
      client.submit(anchor)
      result = client.get(anchor.anchor_hash)

      expect(result[:anchor_type]).to eq('meeting')
      expect(result[:source_id]).to eq('test_001')
      expect(result[:participants]).to eq(['agent_a'])
    end

    it 'returns nil for non-existing anchor' do
      result = client.get('nonexistent_hash')
      expect(result).to be_nil
    end
  end

  describe '#list' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }

    before do
      3.times do |i|
        anchor = HestiaChain::Core::Anchor.new(
          anchor_type: i.even? ? 'meeting' : 'generic',
          source_id: "test_#{i}",
          data_hash: Digest::SHA256.hexdigest("data_#{i}")
        )
        client.submit(anchor)
      end
    end

    it 'lists all anchors' do
      result = client.list
      expect(result.size).to eq(3)
    end

    it 'limits results' do
      result = client.list(limit: 2)
      expect(result.size).to eq(2)
    end

    it 'filters by anchor_type' do
      result = client.list(anchor_type: 'meeting')
      expect(result.all? { |a| a[:anchor_type] == 'meeting' }).to be true
    end
  end

  describe '#anchor (convenience method)' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }

    it 'creates and submits anchor from hash data' do
      result = client.anchor(
        anchor_type: 'research',
        source_id: 'exp_001',
        data: { result: 'success' }
      )

      expect(result[:status]).to eq('submitted')
      expect(result[:anchor_hash]).to match(/\A[a-f0-9]{64}\z/)
    end

    it 'creates and submits anchor from string data' do
      result = client.anchor(
        anchor_type: 'audit',
        source_id: 'log_001',
        data: 'log entry content'
      )

      expect(result[:status]).to eq('submitted')
    end

    it 'accepts additional options' do
      result = client.anchor(
        anchor_type: 'meeting',
        source_id: 'session_001',
        data: 'session data',
        participants: ['a', 'b'],
        metadata: { duration: 300 }
      )

      expect(result[:status]).to eq('submitted')

      stored = client.get(result[:anchor_hash])
      expect(stored[:participants]).to eq(%w[a b])
      expect(stored[:metadata]).to eq({ duration: 300 })
    end
  end

  describe '#status' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }

    it 'returns status information' do
      status = client.status

      expect(status[:enabled]).to be true
      expect(status[:backend]).to eq(:in_memory)
      expect(status[:backend_ready]).to be true
      expect(status[:batch_queue_size]).to eq(0)
    end
  end

  describe '#stats' do
    let(:client) { described_class.new(config: { backend: 'in_memory' }) }

    it 'returns detailed statistics' do
      stats = client.stats

      expect(stats[:client]).to be_a(Hash)
      expect(stats[:backend]).to be_a(Hash)
      expect(stats[:batch_processor]).to be_a(Hash)
    end
  end

  describe '#inspect' do
    it 'returns readable string' do
      client = described_class.new
      expect(client.inspect).to include('HestiaChain::Client')
    end
  end
end
