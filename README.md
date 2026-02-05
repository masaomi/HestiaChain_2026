# HestiaChain

**A Post-Consensus Web3 Infrastructure for Proof-of-Existence and Philosophical Protocol**

[日本語版 README](README_jp.md)

---

## Overview

HestiaChain is a pluggable blockchain anchoring system that enables smooth migration from private storage to public blockchains. It provides two layers:

1. **Core Layer**: Generic proof-of-existence anchoring with pluggable backends
2. **Protocol Layer** (opt-in): Philosophical protocol for inter-agent interaction without consensus

## Design Philosophy

> **"History is not replayable, but reconstructible through cooperation."**

HestiaChain records only hashes (proof of existence), never the actual data. This ensures privacy while enabling auditability through cooperation between participants.

### Beyond DAO

> **"How can we remain connected without deciding the same thing?"**

The optional Protocol layer enables a post-consensus model where:
- Meaning is not agreed upon; meaning coexists
- Multiple interpretations of the same interaction are valid
- Fade-out is a legitimate outcome, not a failure

## Features

### Core Features
- **Pluggable Backends**: Seamlessly switch between storage backends
- **Stage-based Migration**: Move from development to production incrementally
- **Batch Processing**: Optimize gas costs with batched submissions
- **Generic Design**: Use with any application (Meeting Protocol, GenomicsChain, etc.)
- **Privacy-Preserving**: Records only hashes, never content

### Protocol Features (Opt-in)
- **Philosophy Declaration**: Declare exchange philosophies without requiring consensus
- **Observation Logging**: Record subjective observations of interactions
- **Meaning Coexistence**: Support multiple interpretations of the same event
- **Fade-out Support**: Natural relationship decay as a first-class outcome

## Stages

| Stage | Backend | Description |
|-------|---------|-------------|
| 0 | `in_memory` | Development and testing |
| 1 | `private` | JSON file-based storage |
| 2 | `public_testnet` | Ethereum testnet (Base Sepolia) |
| 3 | `public_mainnet` | Ethereum mainnet (Base) |

## Quick Start

### Basic Anchoring

```ruby
require 'hestia_chain'

# Create a client (uses in_memory backend by default)
client = HestiaChain.client

# Create and submit an anchor
result = client.anchor(
  anchor_type: 'research_data',
  source_id: 'experiment_001',
  data: { result: 'success', value: 42 }
)

puts result[:anchor_hash]
# => "a1b2c3d4e5f6..."

# Verify the anchor exists
verification = client.verify(result[:anchor_hash])
puts "Exists: #{verification[:exists]}"
# => "Exists: true"
```

### Philosophy Protocol (Opt-in)

```ruby
require 'hestia_chain'
require 'hestia_chain/protocol'  # Explicitly opt-in

client = HestiaChain.client(backend: 'private')

# 1. Declare your exchange philosophy
declaration = HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'my_agent',
  philosophy_type: 'exchange',
  philosophy_hash: Digest::SHA256.hexdigest(my_philosophy.to_json),
  compatible_with: ['cooperative', 'observational'],
  version: '1.0'
)
client.submit(declaration.to_anchor)

# 2. Record an observation (subjective, not universal)
observation = HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'my_agent',
  observed_id: 'other_agent',
  interaction_hash: Digest::SHA256.hexdigest(interaction.to_json),
  observation_type: 'completed',
  interpretation: { outcome: 'mutual_learning', compatibility: 'high' }
)
client.submit(observation.to_anchor)
```

## Installation

Add to your Gemfile:

```ruby
gem 'hestia_chain', path: '/path/to/HestiaChain_2026'
```

Or install directly:

```bash
cd HestiaChain_2026
bundle install
```

## Configuration

Create `config/hestia_chain.yml`:

```yaml
development:
  enabled: true
  backend: in_memory

staging:
  enabled: true
  backend: private
  private:
    storage_path: storage/hestia_anchors.json

production:
  enabled: true
  backend: public_mainnet
  batching:
    enabled: true
    interval_seconds: 3600
    max_batch_size: 100
  public_mainnet:
    chain: base
    rpc_url: <%= ENV['HESTIA_RPC_URL'] %>
    contract_address: <%= ENV['HESTIA_CONTRACT_ADDRESS'] %>
```

## Anchor Types

### Core Types

| Type | Description |
|------|-------------|
| `meeting` | Agent interaction witnesses |
| `generic` | General purpose anchors |
| `genomics` | Genomic data provenance |
| `research` | Research data proof |
| `agreement` | Contract/agreement signatures |
| `audit` | Audit log entries |
| `release` | Software release hashes |
| `custom.*` | Custom application types |

### Protocol Types (Opt-in)

| Type | Description |
|------|-------------|
| `philosophy_declaration` | Exchange philosophy declarations |
| `observation_log` | Interaction observation records |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Applications (Meeting Protocol, GenomicsChain, KairosChain)    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HestiaChain Protocol (opt-in)                                  │
│  ├── PhilosophyDeclaration                                      │
│  └── ObservationLog                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HestiaChain Core                                               │
│  ├── Client (main interface)                                    │
│  ├── Anchor (data structure)                                    │
│  ├── Config (configuration)                                     │
│  └── BatchProcessor (gas optimization)                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Pluggable Backends                                             │
│  ├── InMemory (Stage 0)                                         │
│  ├── Private (Stage 1)                                          │
│  ├── PublicTestnet (Stage 2)                                    │
│  └── PublicMainnet (Stage 3)                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Storage Layer                                                  │
│  ├── Memory / JSON File                                         │
│  └── Ethereum (Base L2)                                         │
└─────────────────────────────────────────────────────────────────┘
```

## Philosophy Protocol Details

### PhilosophyDeclaration

Declares an agent's exchange philosophy. This is observable, not enforceable.

```ruby
HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'agent_001',           # Declaring agent
  philosophy_type: 'exchange',      # exchange, interaction, or fadeout
  philosophy_hash: '...',           # Hash of philosophy content (content stays private)
  compatible_with: ['cooperative'], # Compatibility tags
  version: '1.0'                    # Version for evolution tracking
)
```

**Philosophy Types:**
- `exchange`: Philosophy about skill exchange and sharing
- `interaction`: Philosophy about general inter-agent interaction
- `fadeout`: Philosophy about disengagement and relationship decay

### ObservationLog

Records subjective observations of interactions. Multiple interpretations can coexist.

```ruby
HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'agent_001',         # Who is observing
  observed_id: 'agent_002',         # Who is being observed
  interaction_hash: '...',          # Hash of interaction data
  observation_type: 'completed',    # initiated, completed, faded, observed
  interpretation: { ... }           # Subjective interpretation
)
```

**Design Principle:** The same interaction can have different observations from different agents. Both are valid.

## Integration Examples

### Meeting Protocol Integration

```ruby
class MeetingProtocolIntegration
  def initialize
    @hestia = HestiaChain.client
  end

  def anchor_session(session)
    @hestia.anchor(
      anchor_type: 'meeting',
      source_id: session[:session_id],
      data: session.to_json,
      participants: [session[:peer_id]],
      metadata: {
        message_count: session[:messages].length,
        started_at: session[:started_at]
      }
    )
  end
end
```

### KairosChain Integration (Future)

```ruby
require 'hestia_chain/protocol'

class KairosChainIntegration
  def declare_exchange_philosophy(agent, philosophy)
    declaration = HestiaChain::Protocol::PhilosophyDeclaration.new(
      agent_id: agent.id,
      philosophy_type: 'exchange',
      philosophy_hash: Digest::SHA256.hexdigest(philosophy.to_json),
      compatible_with: philosophy[:compatible_with]
    )
    @hestia.submit(declaration.to_anchor)
  end

  def record_skill_exchange_observation(observer, observed, interaction)
    observation = HestiaChain::Protocol::ObservationLog.new(
      observer_id: observer.id,
      observed_id: observed.id,
      interaction_hash: Digest::SHA256.hexdigest(interaction.to_json),
      observation_type: 'completed',
      interpretation: observer.interpret(interaction)
    )
    @hestia.submit(observation.to_anchor)
  end
end
```

## Smart Contract

For Stage 2/3 (public blockchain), deploy the HestiaAnchor contract:

```solidity
// contracts/HestiaAnchor.sol
contract HestiaAnchor {
    event AnchorRecorded(bytes32 indexed anchorHash, string indexed anchorType, uint256 timestamp);
    
    mapping(bytes32 => bool) public anchors;
    mapping(bytes32 => uint256) public timestamps;
    
    function recordAnchor(bytes32 anchorHash, string calldata anchorType) external returns (bool);
    function recordAnchors(bytes32[] calldata hashes, string[] calldata types) external returns (uint256);
    function verifyAnchor(bytes32 anchorHash) external view returns (bool, uint256, string memory, address);
}
```

## CLI Tools

```bash
# Generate Ethereum keypair
bin/hestia_keygen

# Check blockchain connection
bin/hestia_check_connection

# Test contract on testnet
bin/hestia_test_contract

# Migrate between backends
bin/hestia_migrate --from private --to public_testnet
```

## Security Considerations

- **Private Keys**: Never commit private keys. Use environment variables.
- **Content Privacy**: HestiaChain only records hashes, never actual content.
- **Batch Security**: Failed batches are re-queued, ensuring no data loss.
- **Philosophy Privacy**: Philosophy content is hashed; only the hash is recorded on-chain.

## FAQ

### Q: How does HestiaChain determine if two agents have compatible philosophies?

**A: HestiaChain does NOT determine compatibility. This is by design.**

HestiaChain only provides:
1. **Declaration recording** - Agents declare their philosophy
2. **Compatibility tags** - `compatible_with: ['cooperative', 'observational']`
3. **Observation recording** - Agents record interaction outcomes

**Compatibility is determined locally by each agent**, not globally by HestiaChain.

This reflects the DEE (Decentralized Evolving Ecosystem) philosophy:

> "Meaning is not agreed upon. Meaning coexists."

| DAO Approach | DEE Approach (HestiaChain) |
|--------------|---------------------------|
| Global compatibility rules | Local judgment by each agent |
| Central "match/no-match" decision | Trial and observation |
| Connection based on consensus | Relationship through experimentation |

**Why this design?**

- No central authority decides what philosophies are "compatible"
- Each agent interprets declarations according to their own philosophy
- Actual compatibility emerges through interaction and observation
- Fade-out is a natural outcome when philosophies don't align

**Expected usage flow:**

```
1. Agent A declares philosophy (HestiaChain)
2. Agent B declares philosophy (HestiaChain)
3. Agent A reads B's declaration and judges locally (KairosChain)
4. Interaction is attempted
5. Both agents record their observations (HestiaChain)
6. Each agent evaluates the relationship by their own criteria
```

The `compatible_with` tags are hints, not enforcement. They enable loose coupling while preserving agent autonomy.

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop

# Run demo
ruby examples/philosophy_protocol_demo.rb
```

## Test Results

```
118 examples, 0 failures
Line Coverage: 82.17%
```

## License

MIT License - See [LICENSE](LICENSE) file.

## Related Projects

- [KairosChain](../KairosChain_2026): Memory-driven agent framework
- [GenomicsChain](https://genomicschain.ch): Decentralized genomic data platform

## References

- [Beyond DAO: Philosophy and Architecture](log/hestia_chain_beyond_dao_en_20260204.md)
- [Implementation Log](log/hestiachain_implementation_log_20260204.md)
- [Protocol Implementation Plan](log/hestiachain_philosophy_protocol_plan_20260204.md)
