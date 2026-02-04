# HestiaChain

**Generic Private to Public Blockchain Migration Module**

HestiaChain provides a pluggable backend system for recording proof-of-existence anchors, enabling smooth migration from private storage to public blockchains.

## Design Philosophy

> **"History is not replayable, but reconstructible through cooperation."**

HestiaChain is designed as a "witness/anchor" module that records only hashes (proof of existence), never the actual data. This ensures privacy while enabling auditability through cooperation between participants.

## Features

- **Pluggable Backends**: Seamlessly switch between storage backends
- **Stage-based Migration**: Move from development to production incrementally
- **Batch Processing**: Optimize gas costs with batched submissions
- **Generic Design**: Use with any application (Meeting Protocol, GenomicsChain, etc.)
- **Privacy-Preserving**: Records only hashes, never content

## Stages

| Stage | Backend | Description |
|-------|---------|-------------|
| 0 | `in_memory` | Development and testing |
| 1 | `private` | JSON file-based storage |
| 2 | `public_testnet` | Ethereum testnet (Base Sepolia) |
| 3 | `public_mainnet` | Ethereum mainnet (Base) |

## Quick Start

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

## Usage Examples

### Basic Anchor

```ruby
require 'hestia_chain'
require 'digest'

client = HestiaChain.client

# Create an anchor manually
anchor = HestiaChain::Core::Anchor.new(
  anchor_type: 'meeting',
  source_id: 'session_abc123',
  data_hash: Digest::SHA256.hexdigest(session_data.to_json),
  participants: ['agent_a', 'agent_b'],
  metadata: { message_count: 42 }
)

# Submit the anchor
result = client.submit(anchor)
```

### Batch Processing

```ruby
# Enable batching for gas optimization
client = HestiaChain.client(
  backend: 'public_mainnet',
  batching: { enabled: true, max_batch_size: 50 }
)

# Queue anchors for batch submission
50.times do |i|
  client.submit(anchor, async: true)
end

# Manually flush the batch
client.flush_batch!
```

### Custom Anchor Types

```ruby
# Use standard types
anchor = HestiaChain.anchor(
  anchor_type: 'genomics',
  source_id: 'nft_001',
  data_hash: nft_metadata_hash
)

# Or define custom types
anchor = HestiaChain.anchor(
  anchor_type: 'custom.my_app.event',
  source_id: 'event_123',
  data_hash: event_hash
)
```

## Standard Anchor Types

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

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Applications (Meeting Protocol, GenomicsChain, etc.)           │
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
│  └── Ethereum (Base, etc.)                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Integration Examples

### Meeting Protocol Integration

```ruby
# In your Meeting Protocol code
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

### GenomicsChain Integration

```ruby
# In your GenomicsChain code
class GenomicsChainIntegration
  def initialize
    @hestia = HestiaChain.client
  end

  def anchor_nft(nft_metadata)
    @hestia.anchor(
      anchor_type: 'genomics',
      source_id: nft_metadata[:token_id],
      data: nft_metadata.to_json,
      metadata: {
        dataset_type: nft_metadata[:dataset_type],
        minted_at: Time.now.iso8601
      }
    )
  end
end
```

## Smart Contract

For Stage 2/3 (public blockchain), deploy the HestiaAnchor contract:

```solidity
// contracts/HestiaAnchor.sol
contract HestiaAnchor {
    event AnchorRecorded(bytes32 indexed anchorHash, uint256 timestamp);
    
    mapping(bytes32 => bool) public anchors;
    mapping(bytes32 => uint256) public timestamps;
    
    function recordAnchor(bytes32 anchorHash) external {
        require(!anchors[anchorHash], "Anchor exists");
        anchors[anchorHash] = true;
        timestamps[anchorHash] = block.timestamp;
        emit AnchorRecorded(anchorHash, block.timestamp);
    }
}
```

## Security Considerations

- **Private Keys**: Never commit private keys. Use environment variables.
- **Content Privacy**: HestiaChain only records hashes, never actual content.
- **Batch Security**: Failed batches are re-queued, ensuring no data loss.

## Development

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run linter
bundle exec rubocop
```

## License

MIT License - See [LICENSE](LICENSE) file.

## Related Projects

- [KairosChain](../KairosChain_2026): Memory-driven agent framework
- [GenomicsChain](https://genomicschain.ch): Decentralized genomic data platform
- [Meeting Protocol (MMP)](../KairosChain_2026/docs/MMP_Specification_Draft_v1.0.md): Agent-to-agent communication protocol
