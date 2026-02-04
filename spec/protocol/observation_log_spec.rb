# frozen_string_literal: true

require 'spec_helper'
require 'hestia_chain'
require 'hestia_chain/protocol'

RSpec.describe HestiaChain::Protocol::ObservationLog do
  let(:valid_hash) { Digest::SHA256.hexdigest('test interaction data') }
  let(:valid_params) do
    {
      observer_id: 'agent_001',
      observed_id: 'agent_002',
      interaction_hash: valid_hash,
      observation_type: 'completed'
    }
  end

  describe '#initialize' do
    context 'with valid parameters' do
      it 'creates an observation with required fields' do
        observation = described_class.new(**valid_params)

        expect(observation.observer_id).to eq('agent_001')
        expect(observation.observed_id).to eq('agent_002')
        expect(observation.interaction_hash).to eq(valid_hash)
        expect(observation.observation_type).to eq('completed')
      end

      it 'sets default values for optional fields' do
        observation = described_class.new(**valid_params)

        expect(observation.interpretation).to eq({})
        expect(observation.timestamp).to match(/\d{4}-\d{2}-\d{2}T/)
        expect(observation.context_ref).to be_nil
        expect(observation.metadata).to eq({})
      end

      it 'accepts optional parameters' do
        observation = described_class.new(
          **valid_params,
          interpretation: { outcome: 'positive' },
          context_ref: 'prev_anchor_hash',
          metadata: { session_id: 'abc123' }
        )

        expect(observation.interpretation).to eq({ outcome: 'positive' })
        expect(observation.context_ref).to eq('prev_anchor_hash')
        expect(observation.metadata).to eq({ session_id: 'abc123' })
      end

      it 'normalizes hash with 0x prefix' do
        observation = described_class.new(
          **valid_params.merge(interaction_hash: "0x#{valid_hash}")
        )

        expect(observation.interaction_hash).to eq(valid_hash)
      end
    end

    context 'with invalid parameters' do
      it 'raises error for empty observer_id' do
        expect {
          described_class.new(**valid_params.merge(observer_id: ''))
        }.to raise_error(ArgumentError, /observer_id cannot be empty/)
      end

      it 'raises error for empty observed_id' do
        expect {
          described_class.new(**valid_params.merge(observed_id: ''))
        }.to raise_error(ArgumentError, /observed_id cannot be empty/)
      end

      it 'raises error for invalid observation_type' do
        expect {
          described_class.new(**valid_params.merge(observation_type: 'invalid'))
        }.to raise_error(ArgumentError, /Invalid observation_type/)
      end

      it 'allows custom. prefixed observation_type' do
        observation = described_class.new(
          **valid_params.merge(observation_type: 'custom.my_type')
        )

        expect(observation.observation_type).to eq('custom.my_type')
      end

      it 'raises error for invalid interaction_hash format' do
        expect {
          described_class.new(**valid_params.merge(interaction_hash: 'not_a_hash'))
        }.to raise_error(ArgumentError, /Invalid interaction_hash format/)
      end
    end
  end

  describe '#observation_id' do
    it 'generates a unique observation ID' do
      observation = described_class.new(**valid_params)
      id = observation.observation_id

      expect(id).to start_with('obs_')
      expect(id.length).to eq(16) # 'obs_' + 12 char hash
    end

    it 'returns the same ID on multiple calls' do
      observation = described_class.new(**valid_params)

      expect(observation.observation_id).to eq(observation.observation_id)
    end

    it 'generates different IDs for different observations' do
      obs1 = described_class.new(**valid_params)
      obs2 = described_class.new(**valid_params.merge(observer_id: 'different_agent'))

      expect(obs1.observation_id).not_to eq(obs2.observation_id)
    end
  end

  describe '#self_observation?' do
    it 'returns true when observer and observed are the same' do
      observation = described_class.new(
        **valid_params.merge(observed_id: 'agent_001')
      )

      expect(observation.self_observation?).to be true
    end

    it 'returns false when observer and observed are different' do
      observation = described_class.new(**valid_params)

      expect(observation.self_observation?).to be false
    end
  end

  describe '#fadeout?' do
    it 'returns true when observation_type is faded' do
      observation = described_class.new(
        **valid_params.merge(observation_type: 'faded')
      )

      expect(observation.fadeout?).to be true
    end

    it 'returns false for other observation types' do
      observation = described_class.new(**valid_params)

      expect(observation.fadeout?).to be false
    end
  end

  describe '#to_anchor' do
    it 'converts to a valid Anchor' do
      observation = described_class.new(**valid_params)
      anchor = observation.to_anchor

      expect(anchor).to be_a(HestiaChain::Core::Anchor)
      expect(anchor.anchor_type).to eq('observation_log')
      expect(anchor.source_id).to eq(observation.observation_id)
      expect(anchor.data_hash).to eq(valid_hash)
    end

    it 'includes both participants for non-self observation' do
      observation = described_class.new(**valid_params)
      anchor = observation.to_anchor

      expect(anchor.participants).to contain_exactly('agent_001', 'agent_002')
    end

    it 'includes only observer for self-observation' do
      observation = described_class.new(
        **valid_params.merge(observed_id: 'agent_001')
      )
      anchor = observation.to_anchor

      expect(anchor.participants).to eq(['agent_001'])
    end

    it 'includes metadata in the anchor' do
      observation = described_class.new(
        **valid_params,
        interpretation: { outcome: 'positive' }
      )
      anchor = observation.to_anchor

      expect(anchor.metadata[:observation_type]).to eq('completed')
      expect(anchor.metadata[:observer_id]).to eq('agent_001')
      expect(anchor.metadata[:observed_id]).to eq('agent_002')
      expect(anchor.metadata[:interpretation_hash]).to be_a(String)
    end

    it 'sets context_ref as previous_anchor_ref' do
      observation = described_class.new(
        **valid_params,
        context_ref: 'previous_anchor_hash'
      )
      anchor = observation.to_anchor

      expect(anchor.previous_anchor_ref).to eq('previous_anchor_hash')
    end
  end

  describe '#to_h' do
    it 'returns a hash representation' do
      observation = described_class.new(**valid_params)
      hash = observation.to_h

      expect(hash[:observer_id]).to eq('agent_001')
      expect(hash[:observed_id]).to eq('agent_002')
      expect(hash[:interaction_hash]).to eq(valid_hash)
      expect(hash[:observation_type]).to eq('completed')
      expect(hash[:observation_id]).to eq(observation.observation_id)
    end
  end

  describe '#to_json' do
    it 'returns a JSON string' do
      observation = described_class.new(**valid_params)
      json = observation.to_json
      parsed = JSON.parse(json)

      expect(parsed['observer_id']).to eq('agent_001')
      expect(parsed['observation_type']).to eq('completed')
    end
  end

  describe '.from_h' do
    it 'creates an observation from a hash' do
      original = described_class.new(
        **valid_params,
        interpretation: { outcome: 'positive' }
      )
      recreated = described_class.from_h(original.to_h)

      expect(recreated.observer_id).to eq(original.observer_id)
      expect(recreated.observed_id).to eq(original.observed_id)
      expect(recreated.interaction_hash).to eq(original.interaction_hash)
      expect(recreated.observation_type).to eq(original.observation_type)
    end

    it 'handles string keys' do
      hash = {
        'observer_id' => 'agent_001',
        'observed_id' => 'agent_002',
        'interaction_hash' => valid_hash,
        'observation_type' => 'completed'
      }
      observation = described_class.from_h(hash)

      expect(observation.observer_id).to eq('agent_001')
    end
  end

  describe '#inspect' do
    it 'returns a readable string for non-self observation' do
      observation = described_class.new(**valid_params)

      expect(observation.inspect).to include('ObservationLog')
      expect(observation.inspect).to include('completed')
      expect(observation.inspect).to include('agent_001->agent_002')
    end

    it 'returns a readable string for self-observation' do
      observation = described_class.new(
        **valid_params.merge(observed_id: 'agent_001')
      )

      expect(observation.inspect).to include('self')
    end
  end

  describe 'observation types' do
    %w[initiated completed faded observed].each do |type|
      it "accepts '#{type}' as a valid observation_type" do
        observation = described_class.new(
          **valid_params.merge(observation_type: type)
        )

        expect(observation.observation_type).to eq(type)
      end
    end
  end

  describe 'design philosophy: meaning coexistence' do
    it 'allows multiple observations of the same interaction' do
      # Same interaction can have different interpretations from different observers
      interaction_data = { event: 'skill_exchange', participants: %w[a b] }
      interaction_hash = Digest::SHA256.hexdigest(interaction_data.to_json)

      obs1 = described_class.new(
        observer_id: 'agent_a',
        observed_id: 'agent_b',
        interaction_hash: interaction_hash,
        observation_type: 'completed',
        interpretation: { outcome: 'successful', learned: true }
      )

      obs2 = described_class.new(
        observer_id: 'agent_b',
        observed_id: 'agent_a',
        interaction_hash: interaction_hash,
        observation_type: 'completed',
        interpretation: { outcome: 'partial', needs_refinement: true }
      )

      # Both observations are valid - meaning coexists
      expect(obs1.to_anchor).to be_valid
      expect(obs2.to_anchor).to be_valid

      # Different interpretations of the same event
      expect(obs1.interpretation[:outcome]).not_to eq(obs2.interpretation[:outcome])

      # Same underlying interaction
      expect(obs1.interaction_hash).to eq(obs2.interaction_hash)
    end
  end
end
