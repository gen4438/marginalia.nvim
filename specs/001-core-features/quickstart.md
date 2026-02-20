# クイックスタート: コア機能

**ブランチ**: `001-core-features` | **日付**: 2026-02-19
**仕様書**: [specs/001-core-features/spec.md](./spec.md)

## 開発セットアップ

1.  **リポジトリのクローン**:
    ```bash
    git clone https://github.com/user/marginalia.nvim.git
    cd marginalia.nvim
    ```

2.  **依存関係**:
    `plenary.nvim` がインストールされていることを確認してください。テストには、ローカルの `plenary.nvim` クローンを使用するか、プラグインマネージャーに依存します。
    開発用の依存関係管理には `lazy.nvim` または `packer.nvim` を推奨します。

3.  **テストの実行 (TDD)**:
    bustedスタイルのテストを実行するために `plenary.test_harness` を使用します。

    `Makefile` が提供されています（または作成する必要があります）:
    ```bash
    make test
    # または手動で実行
    nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/marginalia { minimal_init = 'tests/minimal_init.lua' }"
    ```

    **TDD ワークフロー**:
    1.  `tests/marginalia/` にスペックファイルを作成する。
    2.  `make test` を実行する。失敗することを確認する。
    3.  `lua/marginalia/` に機能を実装する。
    4.  パスするまで `make test` を実行する。

## ローカルでプラグインを試す

1.  Neovimの設定にローカルディレクトリを追加する:
    ```lua
    -- plugins.lua (lazy.nvim の例)
    {
      dir = "~/path/to/marginalia.nvim",
      config = function()
        require("marginalia").setup({})
      end
    }
    ```
2.  ファイルを開き、ビジュアルモードで行を選択する。
3.  `:lua require('marginalia').annotate_selection()` を実行する。
4.  コメントを入力する。
5.  `:messages` またはクリップボードを確認する。

## キーファイル

*   `lua/marginalia/init.lua`: メインエントリーポイント。
*   `lua/marginalia/core/capture.lua`: コアロジック。
*   `tests/marginalia/`: スペック（テスト）。
