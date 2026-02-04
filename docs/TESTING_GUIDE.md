# HestiaChain Testing Guide

Base Sepolia テストネットでの動作確認手順です。

## 前提条件

- Ruby 3.x
- Node.js 18+（Contract デプロイ用）
- bundler

## Step 1: セットアップ

```bash
cd HestiaChain_2026

# Ruby 依存関係のインストール
bundle install

# Contract 用依存関係のインストール
cd contracts
pnpm install
cd ..
```

## Step 2: 秘密鍵の生成

```bash
# 新しい秘密鍵を生成
bin/hestia_keygen

# または、ファイルに保存
bin/hestia_keygen --output .env.local

# 環境変数を設定
export HESTIA_TESTNET_PRIVATE_KEY="生成された秘密鍵"
```

**重要**: 秘密鍵は絶対に git にコミットしないでください。

## Step 3: テスト ETH の取得

1. 生成された Address をコピー
2. Faucet にアクセス: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
3. Address を入力してテスト ETH を取得

## Step 4: 接続確認

```bash
bin/hestia_check_connection
```

期待される出力:
```
Account Address: 0x...
Testing network connections...
  base_sepolia   : OK - Base Sepolia (Testnet)
                   Balance: 0.100000 ETH
```

Balance が 0 の場合は Step 3 を再実行してください。

## Step 5: Smart Contract のデプロイ

```bash
cd contracts

# 環境変数を設定（Hardhat 用）
export PRIVATE_KEY=$HESTIA_TESTNET_PRIVATE_KEY

# Base Sepolia にデプロイ
pnpm exec hardhat run scripts/deploy.js --network base_sepolia
```

出力例:
```
Deploying HestiaAnchor contract...
Contract address: 0x1234567890abcdef...
```

**Contract Address を控えておいてください。**

```bash
# 環境変数に設定
export HESTIA_CONTRACT_ADDRESS="デプロイされたアドレス"

cd ..
```

## Step 6: 統合テスト

```bash
bin/hestia_test_contract
```

このスクリプトは以下をテストします:
1. Contract への接続
2. Anchor の作成とブロックチェーンへの記録
3. Anchor の検証

## Step 7: エクスプローラーで確認

デプロイした Contract とトランザクションはエクスプローラーで確認できます:

```
https://sepolia.basescan.org/address/YOUR_CONTRACT_ADDRESS
```

## トラブルシューティング

### "No balance" エラー

Faucet からテスト ETH を取得してください。1回で足りない場合は、時間をおいて再度取得できます。

### "Transaction failed" エラー

- ガス代が足りない可能性があります
- Anchor が既に存在する可能性があります
- ネットワークが混雑している可能性があります（少し待って再試行）

### "Connection refused" エラー

RPC URL に問題がある可能性があります。以下の代替 URL を試してください:
- `https://sepolia.base.org`
- `https://base-sepolia.g.alchemy.com/v2/demo`

### Contract のデプロイに失敗

- PRIVATE_KEY 環境変数が正しく設定されているか確認
- テスト ETH の残高を確認
- Hardhat の設定を確認

## 次のステップ

テストが成功したら:
1. KairosChain との統合（ユーザー確認後）
2. 本番環境（Base Mainnet）へのデプロイ

## 参考リンク

- [Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
- [Base Sepolia Explorer](https://sepolia.basescan.org/)
- [eth gem documentation](https://github.com/q9f/eth.rb)
- [Hardhat documentation](https://hardhat.org/docs)
