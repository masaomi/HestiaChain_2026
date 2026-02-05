# HestiaChain

**ポスト・コンセンサス型 Web3 インフラストラクチャ：存在証明と哲学的プロトコル**

[English README](README.md)

---

## 概要

HestiaChain は、プライベートストレージからパブリックブロックチェーンへのスムーズな移行を可能にする、プラガブルなブロックチェーンアンカリングシステムです。2つのレイヤーを提供します：

1. **Core レイヤー**: プラガブルなバックエンドを持つ汎用的な存在証明アンカリング
2. **Protocol レイヤー**（オプトイン）: 合意を必要としないエージェント間相互作用のための哲学的プロトコル

## 設計思想

> **「歴史は再生不能だが、協力によって再構築可能である」**

HestiaChain はハッシュ（存在証明）のみを記録し、実際のデータは決して記録しません。これにより、参加者間の協力を通じた監査可能性を確保しつつ、プライバシーを保護します。

### Beyond DAO

> **「同じことを決めなくても、どうすれば接続し続けられるか？」**

オプションの Protocol レイヤーは、以下のようなポスト・コンセンサスモデルを実現します：
- 意味は合意されない；意味は併存する
- 同じ相互作用に対する複数の解釈が有効
- フェードアウト（関係の自然消滅）は失敗ではなく、正当な結果

## 機能

### Core 機能
- **プラガブルバックエンド**: ストレージバックエンドをシームレスに切り替え
- **段階的移行**: 開発から本番へ段階的に移行
- **バッチ処理**: バッチ送信によるガスコストの最適化
- **汎用設計**: あらゆるアプリケーションで使用可能（Meeting Protocol、GenomicsChain等）
- **プライバシー保護**: コンテンツではなくハッシュのみを記録

### Protocol 機能（オプトイン）
- **哲学宣言**: 合意を必要とせずに交換哲学を宣言
- **観測ログ**: 相互作用の主観的な観測を記録
- **意味の併存**: 同じイベントの複数の解釈をサポート
- **フェードアウト対応**: 関係の自然な衰退を第一級の結果として扱う

## ステージ

| ステージ | バックエンド | 説明 |
|---------|------------|------|
| 0 | `in_memory` | 開発・テスト用 |
| 1 | `private` | JSONファイルベースのストレージ |
| 2 | `public_testnet` | Ethereumテストネット（Base Sepolia） |
| 3 | `public_mainnet` | Ethereumメインネット（Base） |

## クイックスタート

### 基本的なアンカリング

```ruby
require 'hestia_chain'

# クライアント作成（デフォルトでin_memoryバックエンドを使用）
client = HestiaChain.client

# アンカーを作成して送信
result = client.anchor(
  anchor_type: 'research_data',
  source_id: 'experiment_001',
  data: { result: 'success', value: 42 }
)

puts result[:anchor_hash]
# => "a1b2c3d4e5f6..."

# アンカーの存在を検証
verification = client.verify(result[:anchor_hash])
puts "存在: #{verification[:exists]}"
# => "存在: true"
```

### 哲学プロトコル（オプトイン）

```ruby
require 'hestia_chain'
require 'hestia_chain/protocol'  # 明示的にオプトイン

client = HestiaChain.client(backend: 'private')

# 1. 交換哲学を宣言
declaration = HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'my_agent',
  philosophy_type: 'exchange',
  philosophy_hash: Digest::SHA256.hexdigest(my_philosophy.to_json),
  compatible_with: ['cooperative', 'observational'],
  version: '1.0'
)
client.submit(declaration.to_anchor)

# 2. 観測を記録（主観的、普遍的ではない）
observation = HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'my_agent',
  observed_id: 'other_agent',
  interaction_hash: Digest::SHA256.hexdigest(interaction.to_json),
  observation_type: 'completed',
  interpretation: { outcome: 'mutual_learning', compatibility: 'high' }
)
client.submit(observation.to_anchor)
```

## インストール

Gemfile に追加：

```ruby
gem 'hestia_chain', path: '/path/to/HestiaChain_2026'
```

または直接インストール：

```bash
cd HestiaChain_2026
bundle install
```

## 設定

`config/hestia_chain.yml` を作成：

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

## アンカータイプ

### Core タイプ

| タイプ | 説明 |
|--------|------|
| `meeting` | エージェント間相互作用の証跡 |
| `generic` | 汎用アンカー |
| `genomics` | ゲノムデータの来歴 |
| `research` | 研究データの証明 |
| `agreement` | 契約・合意の署名 |
| `audit` | 監査ログエントリ |
| `release` | ソフトウェアリリースのハッシュ |
| `custom.*` | カスタムアプリケーションタイプ |

### Protocol タイプ（オプトイン）

| タイプ | 説明 |
|--------|------|
| `philosophy_declaration` | 交換哲学の宣言 |
| `observation_log` | 相互作用観測の記録 |

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│  アプリケーション（Meeting Protocol, GenomicsChain, KairosChain） │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HestiaChain Protocol（オプトイン）                               │
│  ├── PhilosophyDeclaration（哲学宣言）                           │
│  └── ObservationLog（観測ログ）                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  HestiaChain Core                                               │
│  ├── Client（メインインターフェース）                              │
│  ├── Anchor（データ構造）                                        │
│  ├── Config（設定管理）                                          │
│  └── BatchProcessor（ガス最適化）                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  プラガブルバックエンド                                           │
│  ├── InMemory（ステージ 0）                                      │
│  ├── Private（ステージ 1）                                       │
│  ├── PublicTestnet（ステージ 2）                                 │
│  └── PublicMainnet（ステージ 3）                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  ストレージレイヤー                                               │
│  ├── メモリ / JSONファイル                                       │
│  └── Ethereum（Base L2）                                        │
└─────────────────────────────────────────────────────────────────┘
```

## 哲学プロトコルの詳細

### PhilosophyDeclaration（哲学宣言）

エージェントの交換哲学を宣言します。これは観測可能ですが、強制はされません。

```ruby
HestiaChain::Protocol::PhilosophyDeclaration.new(
  agent_id: 'agent_001',           # 宣言するエージェント
  philosophy_type: 'exchange',      # exchange, interaction, fadeout
  philosophy_hash: '...',           # 哲学内容のハッシュ（内容自体は非公開）
  compatible_with: ['cooperative'], # 互換性タグ
  version: '1.0'                    # 進化追跡のためのバージョン
)
```

**哲学タイプ：**
- `exchange`: スキル交換・共有に関する哲学
- `interaction`: 一般的なエージェント間相互作用に関する哲学
- `fadeout`: 離脱・関係の衰退に関する哲学

### ObservationLog（観測ログ）

相互作用の主観的な観測を記録します。複数の解釈が併存可能です。

```ruby
HestiaChain::Protocol::ObservationLog.new(
  observer_id: 'agent_001',         # 観測者
  observed_id: 'agent_002',         # 観測対象
  interaction_hash: '...',          # 相互作用データのハッシュ
  observation_type: 'completed',    # initiated, completed, faded, observed
  interpretation: { ... }           # 主観的な解釈
)
```

**設計原則：** 同じ相互作用に対して、異なるエージェントから異なる観測が可能です。両方とも有効です。

## 統合例

### Meeting Protocol 統合

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

### KairosChain 統合（将来）

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

## スマートコントラクト

ステージ 2/3（パブリックブロックチェーン）では、HestiaAnchor コントラクトをデプロイします：

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

## CLI ツール

```bash
# Ethereumキーペアを生成
bin/hestia_keygen

# ブロックチェーン接続を確認
bin/hestia_check_connection

# テストネットでコントラクトをテスト
bin/hestia_test_contract

# バックエンド間で移行
bin/hestia_migrate --from private --to public_testnet
```

## セキュリティに関する考慮事項

- **秘密鍵**: 秘密鍵は決してコミットしない。環境変数を使用する。
- **コンテンツプライバシー**: HestiaChain はハッシュのみを記録し、実際のコンテンツは記録しない。
- **バッチセキュリティ**: 失敗したバッチは再キューされ、データ損失を防ぐ。
- **哲学プライバシー**: 哲学の内容はハッシュ化され、ハッシュのみがオンチェーンに記録される。

## FAQ

### Q: HestiaChain は、2つのエージェントの哲学が互換性があるかどうかをどのように判定しますか？

**A: HestiaChain は互換性を判定しません。これは意図的な設計です。**

HestiaChain が提供するのは以下のみです：
1. **宣言の記録** - エージェントが自分の哲学を宣言
2. **互換性タグ** - `compatible_with: ['cooperative', 'observational']`
3. **観測の記録** - エージェントが相互作用の結果を記録

**互換性は HestiaChain ではなく、各エージェントがローカルで判断します。**

これは DEE（Decentralized Evolving Ecosystem：分散型進化生態系）の哲学を反映しています：

> 「意味は合意されない。意味は併存する。」

| DAO 的アプローチ | DEE 的アプローチ（HestiaChain） |
|----------------|------------------------------|
| グローバルな互換性ルール | 各エージェントによるローカルな判断 |
| 中央で「合う/合わない」を決定 | 試行と観測に基づく |
| 合意に基づく接続 | 実験を通じた関係構築 |

**なぜこの設計なのか？**

- どの哲学が「互換性がある」かを中央で決める権威は存在しない
- 各エージェントは自分の哲学に従って宣言を解釈する
- 実際の互換性は相互作用と観測を通じて浮かび上がる
- 哲学が合わない場合、フェードアウトは自然な結果

**想定される使用フロー：**

```
1. Agent A が哲学を宣言（HestiaChain）
2. Agent B が哲学を宣言（HestiaChain）
3. Agent A は B の宣言を読み、ローカルで判断（KairosChain側）
4. 相互作用を試みる
5. 両エージェントが自分の観測を記録（HestiaChain）
6. 各エージェントが自分の基準で関係を評価
```

`compatible_with` タグはヒントであり、強制ではありません。エージェントの自律性を保ちつつ、緩やかな結合を可能にします。

## 開発

```bash
# 依存関係をインストール
bundle install

# テストを実行
bundle exec rspec

# リンターを実行
bundle exec rubocop

# デモを実行
ruby examples/philosophy_protocol_demo.rb
```

## テスト結果

```
118 examples, 0 failures
Line Coverage: 82.17%
```

## ライセンス

MIT License - [LICENSE](LICENSE) ファイルを参照。

## 関連プロジェクト

- [KairosChain](../KairosChain_2026): メモリ駆動型エージェントフレームワーク
- [GenomicsChain](https://genomicschain.ch): 分散型ゲノムデータプラットフォーム

## 参考資料

- [Beyond DAO: 哲学とアーキテクチャ](log/hestia_chain_beyond_dao_jp_20260204.md)
- [実装ログ](log/hestiachain_implementation_log_20260204.md)
- [Protocol 実装計画](log/hestiachain_philosophy_protocol_plan_20260204.md)

---

## 哲学的要約

- 秩序は合意を必要としない
- 安定は揺らぎから生まれる
- 対立は解消されなくても生き延びられる
- 意味は与えられるものではなく、生成されるもの

> **合意によって秩序を作る社会から、関係の揺らぎによって秩序が立ち上がる社会へ**
