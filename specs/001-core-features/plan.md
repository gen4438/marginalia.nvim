# 実装計画: コア機能

**ブランチ**: `001-core-features` | **日付**: 2026-02-19 | **仕様書**: [specs/001-core-features/spec.md](./spec.md)
**入力**: `proposal.md` の機能説明およびユーザー要件。

**注記**: このテンプレートは `/speckit.plan` コマンドによって入力されます。実行ワークフローについては `.specify/templates/plan-template.md` を参照してください。

## 概要

コードを選択し、注釈を追加し、AI用のMarkdownテキストを生成するプラグイン `marginalia.nvim` のコアロジックを実装します。
主要コンポーネント:
1.  **選択と入力**: ビジュアルモード処理と、複数行入力可能なフローティングウィンドウによるユーザー入力のキャプチャ。
2.  **状態管理**: プロジェクトごとの注釈の保存（インメモリ + `stdpath('data')`へのJSON永続化）。
3.  **生成**: コードとコメントをMarkdownに結合するフォーマッター（固定テンプレート）。
4.  **インターフェース**: 注釈を確認するためのQuickfixリスト統合および完全展開された編集可能バッファ。
5.  **出力**: クリップボード統合。
**アプローチ**: 純粋なLuaによる実装とし、要求通り **テスト駆動開発 (TDD)** を厳守します。

## 技術的コンテキスト

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**言語/バージョン**: Lua (Neovim >= 0.9.0)
**主要な依存関係**:
*   `plenary.nvim` (テストおよびパスユーティリティ用)
*   標準 Neovim APIs (`vim.ui`, `vim.api`, `vim.fn`)
**ストレージ**: `stdpath('data')` 配下のJSONファイルによる永続化。
**テスト**: `plenary.nvim` (busted) - **必須: テストファーストアプローチ**。
**ターゲットプラットフォーム**: Neovim (Linux, macOS, Windows)。
**プロジェクトタイプ**: Neovim プラグイン。
**パフォーマンス目標**: コンテキスト生成 < 100ms。ノンブロッキング入力。
**制約**: 外部ランタイムなし (Python/Nodeなし)。純粋なLua。
**規模/スコープ**: コア機能 (MVP)。

## 憲章チェック

*ゲート: フェーズ0の調査前に合格する必要があります。フェーズ1の設計後に再確認します。*

*   **I. Context First (コンテキスト・ファースト)**: 準拠。コア機能はコードにコンテキストを追加することです。
*   **II. Frictionless Workflow (摩擦のないワークフロー)**: 準拠。ビジュアルモードと、慣れ親しんだバッファ操作（:w, :q）による入力を使用します。
*   **III. Standard UI (標準UIの活用)**: 準拠。フローティングウィンドウ（バッファ）とQuickfixリストを使用します。
*   **IV. Output Agnostic (出力の柔軟性)**: 準拠。クリップボードとバッファ出力をサポートします。
*   **V. Lua Native (Luaネイティブ)**: 準拠。純粋なLuaです。
*   **VI. Test Driven (テスト駆動)**: **重要**。計画等はTDDを明示的に強制しています。

すべてのゲートを通過しました。

## プロジェクト構造

### ドキュメント (この機能)

```text
specs/001-core-features/
├── plan.md              # このファイル
├── research.md          # フェーズ0 成果物
├── data-model.md        # フェーズ1 成果物
├── quickstart.md        # フェーズ1 成果物
├── contracts/           # フェーズ1 成果物
└── tasks.md             # フェーズ2 成果物
```

### ソースコード (リポジトリルート)

```text
lua/
└── marginalia/
    ├── init.lua          # エントリーポイント (setup)
    ├── core/
    │   ├── capture.lua   # 選択範囲 & 入力処理
    │   ├── store.lua     # 状態管理 & 永続化
    │   └── generate.lua  # Markdown生成ロジック
    ├── ui/
    │   ├── display.lua   # Quickfix & バッファ統合
    │   └── input.lua     # 入力ラッパー
    └── utils/
        └── project.lua   # プロジェクトルート検出

tests/
├── minimal_init.lua      # Plenary テスト設定
└── marginalia/
    ├── capture_spec.lua
    ├── store_spec.lua
    ├── generate_spec.lua
    └── integration_spec.lua
```

**構造の決定**: モダンな標準的Neovimプラグイン構造。名前空間として `lua/marginalia` を使用。コアロジックをUIおよびUtilsから分離。テストも同様の構造を反映。

## 複雑性追跡

> **憲章チェックで正当化が必要な違反がある場合のみ記入**

| 違反 | 必要理由 | より単純な代替案を却下した理由 |
|------|----------|--------------------------------|
| N/A | | |
