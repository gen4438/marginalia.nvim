# marginalia.nvim Constitution
<!-- Sync Impact Report:
New Version: 0.1.0 (TDD Principle Added)
Modified Principles: Added VI. Test Driven
Added Sections: None
Templates Checked: plan-template.md (Confirmed TDD alignment)
Follow-up: Ensure test infrastructure (busted/plenary) is set up first
-->

## Core Principles

### I. Context First (コンテキスト・ファースト)
コード単体では不十分である。常にメタデータ（ファイルパス、行番号）とユーザーの意図（注釈）を含めることで、AIの理解を最大化する。

### II. Frictionless Workflow (摩擦のないワークフロー)
ユーザーをエディタから離脱させない。選択、注釈、生成のプロセスは、Neovimのモーダル編集フローの中で完結しなければならない。

### III. Standard UI (標準UIの活用)
複雑な独自UIを避ける。`vim.ui.input`、`vim.ui.select`、標準バッファやQuickfixリストを使用し、互換性と軽量な動作を保証する。

### IV. Output Agnostic (出力の柔軟性)
プラグインはテキストを生成する責務を持ち、その出力先（クリップボード、バッファ、外部コマンド）を強制しない。容易な統合のためのインターフェースを提供する。

### V. Lua Native (Luaネイティブ)
純粋なLuaで記述し、Neovimの最新APIを活用することで、パフォーマンスと保守性を高める。外部依存（Python/Nodeプロバイダー等）は極力避ける。

### VI. Test Driven (テスト駆動)
機能実装の前に必ずテストを作成する（Test First）。**Red-Green-Refactor** のサイクルを厳守し、テストによって動作が保証されたコードのみをコミットする。

## Technical Constraints (技術的制約)

*   **Target Version**: Neovim >= 0.9.0
*   **Dependencies**: 外部依存（Python/Node等）を持たず、Luaのみで動作すること。
*   **Configuration**: ユーザー設定は `setup()` 関数を通じて行う標準的な方式を採用する。
*   **Language**: コード内のコメントおよびドキュメントは日本語で記述する。

## Development Workflow (開発ワークフロー)

*   **Documentation**: READMEおよびヘルプドキュメントは日本語で記述し、わかりやすさを優先する。
*   **Testing**: Plenary.nvim等の標準的なテストフレームワークを使用し、主要機能の動作を保証する。
*   **TDD Workflow**: 新機能およびバグ修正は、必ず失敗するテストケースの作成から開始する。テストのない機能コードの追加は認められない。
*   **Commits**: Conventional Commitsに従う。

## Governance

本憲章はプロジェクトの最高規則であり、すべての設計判断はこれに準拠する必要がある。原則の変更は、ドキュメント化と承認プロセスを経た上で、セマンティックバージョニングに従ってバージョンアップを行う。

**Version**: 0.1.0 | **Ratified**: 2026-02-19 | **Last Amended**: 2026-02-19
