# frozen_string_literal: true

require 'spec_helper'
require 'hestia_chain'
require 'hestia_chain/protocol'

RSpec.describe HestiaChain::Protocol::PhilosophyDeclaration do
  let(:valid_hash) { Digest::SHA256.hexdigest('test philosophy content') }
  let(:valid_params) do
    {
      agent_id: 'test_agent_001',
      philosophy_type: 'exchange',
      philosophy_hash: valid_hash
    }
  end

  describe '#initialize' do
    context 'with valid parameters' do
      it 'creates a declaration with required fields' do
        declaration = described_class.new(**valid_params)

        expect(declaration.agent_id).to eq('test_agent_001')
        expect(declaration.philosophy_type).to eq('exchange')
        expect(declaration.philosophy_hash).to eq(valid_hash)
      end

      it 'sets default values for optional fields' do
        declaration = described_class.new(**valid_params)

        expect(declaration.compatible_with).to eq([])
        expect(declaration.version).to eq('1.0')
        expect(declaration.timestamp).to match(/\d{4}-\d{2}-\d{2}T/)
        expect(declaration.previous_declaration_ref).to be_nil
        expect(declaration.metadata).to eq({})
      end

      it 'accepts optional parameters' do
        declaration = described_class.new(
          **valid_params,
          compatible_with: %w[cooperative observational],
          version: '2.0',
          metadata: { custom_key: 'value' }
        )

        expect(declaration.compatible_with).to eq(%w[cooperative observational])
        expect(declaration.version).to eq('2.0')
        expect(declaration.metadata).to eq({ custom_key: 'value' })
      end

      it 'normalizes hash with 0x prefix' do
        declaration = described_class.new(
          **valid_params.merge(philosophy_hash: "0x#{valid_hash}")
        )

        expect(declaration.philosophy_hash).to eq(valid_hash)
      end
    end

    context 'with invalid parameters' do
      it 'raises error for empty agent_id' do
        expect {
          described_class.new(**valid_params.merge(agent_id: ''))
        }.to raise_error(ArgumentError, /agent_id cannot be empty/)
      end

      it 'raises error for nil agent_id' do
        expect {
          described_class.new(**valid_params.merge(agent_id: nil))
        }.to raise_error(ArgumentError, /agent_id cannot be empty/)
      end

      it 'raises error for invalid philosophy_type' do
        expect {
          described_class.new(**valid_params.merge(philosophy_type: 'invalid'))
        }.to raise_error(ArgumentError, /Invalid philosophy_type/)
      end

      it 'allows custom. prefixed philosophy_type' do
        declaration = described_class.new(
          **valid_params.merge(philosophy_type: 'custom.my_type')
        )

        expect(declaration.philosophy_type).to eq('custom.my_type')
      end

      it 'raises error for invalid philosophy_hash format' do
        expect {
          described_class.new(**valid_params.merge(philosophy_hash: 'not_a_hash'))
        }.to raise_error(ArgumentError, /Invalid philosophy_hash format/)
      end
    end
  end

  describe '#declaration_id' do
    it 'generates a unique declaration ID' do
      declaration = described_class.new(**valid_params)
      id = declaration.declaration_id

      expect(id).to start_with('philo_test_agent_001_exchange_1.0_')
      expect(id).to match(/philo_test_agent_001_exchange_1\.0_\d+/)
    end

    it 'returns the same ID on multiple calls' do
      declaration = described_class.new(**valid_params)

      expect(declaration.declaration_id).to eq(declaration.declaration_id)
    end
  end

  describe '#to_anchor' do
    it 'converts to a valid Anchor' do
      declaration = described_class.new(
        **valid_params,
        compatible_with: ['cooperative']
      )
      anchor = declaration.to_anchor

      expect(anchor).to be_a(HestiaChain::Core::Anchor)
      expect(anchor.anchor_type).to eq('philosophy_declaration')
      expect(anchor.source_id).to eq(declaration.declaration_id)
      expect(anchor.data_hash).to eq(valid_hash)
      expect(anchor.participants).to eq(['test_agent_001'])
    end

    it 'includes metadata in the anchor' do
      declaration = described_class.new(
        **valid_params,
        compatible_with: ['cooperative'],
        version: '2.0'
      )
      anchor = declaration.to_anchor

      expect(anchor.metadata[:philosophy_type]).to eq('exchange')
      expect(anchor.metadata[:compatible_with]).to eq(['cooperative'])
      expect(anchor.metadata[:version]).to eq('2.0')
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      declaration = described_class.new(**valid_params)
      hash = declaration.to_h

      expect(hash[:agent_id]).to eq('test_agent_001')
      expect(hash[:philosophy_type]).to eq('exchange')
      expect(hash[:philosophy_hash]).to eq(valid_hash)
      expect(hash[:declaration_id]).to eq(declaration.declaration_id)
    end
  end

  describe '#to_json' do
    it 'returns a JSON string' do
      declaration = described_class.new(**valid_params)
      json = declaration.to_json
      parsed = JSON.parse(json)

      expect(parsed['agent_id']).to eq('test_agent_001')
      expect(parsed['philosophy_type']).to eq('exchange')
    end
  end

  describe '.from_h' do
    it 'creates a declaration from a hash' do
      original = described_class.new(
        **valid_params,
        compatible_with: ['cooperative'],
        version: '2.0'
      )
      recreated = described_class.from_h(original.to_h)

      expect(recreated.agent_id).to eq(original.agent_id)
      expect(recreated.philosophy_type).to eq(original.philosophy_type)
      expect(recreated.philosophy_hash).to eq(original.philosophy_hash)
      expect(recreated.compatible_with).to eq(original.compatible_with)
      expect(recreated.version).to eq(original.version)
    end

    it 'handles string keys' do
      hash = {
        'agent_id' => 'test_agent',
        'philosophy_type' => 'exchange',
        'philosophy_hash' => valid_hash
      }
      declaration = described_class.from_h(hash)

      expect(declaration.agent_id).to eq('test_agent')
    end
  end

  describe '#inspect' do
    it 'returns a readable string' do
      declaration = described_class.new(**valid_params)

      expect(declaration.inspect).to include('PhilosophyDeclaration')
      expect(declaration.inspect).to include('test_agent_001')
      expect(declaration.inspect).to include('exchange')
    end
  end

  describe 'philosophy types' do
    %w[exchange interaction fadeout].each do |type|
      it "accepts '#{type}' as a valid philosophy_type" do
        declaration = described_class.new(
          **valid_params.merge(philosophy_type: type)
        )

        expect(declaration.philosophy_type).to eq(type)
      end
    end
  end
end
