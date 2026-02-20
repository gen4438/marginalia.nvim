# データモデル: コア機能

**ブランチ**: `001-core-features` | **日付**: 2026-02-19
**仕様書**: [specs/001-core-features/spec.md](./spec.md)

## エンティティ

### Annotation (注釈)

コードブロックに付与される単一の注釈を表します。

| フィールド | 型 | 説明 | 必須 | 検証 |
|------------|----|------|------|------|
| `id` | `string` | 一意の識別子 (UUID v4 またはハッシュ) | はい | 空でないこと |
| `file_path` | `string` | プロジェクトルートからの相対パス | はい | 存在すること |
| `line_start` | `number` | 開始行番号 (1-based) | はい | > 0 |
| `line_end` | `number` | 終了行番号 (1-based) | はい | >= line_start |
| `code_content` | `string` | 元のコード内容 | はい | 空でないこと |
| `comment` | `string` | ユーザーが入力したコメント | はい | 最大1000文字 |
| `created_at` | `number` | エポックタイムスタンプ | はい | 過去/現在 |
| `updated_at` | `number` | エポックタイムスタンプ | はい | >= created_at |

### ProjectStore (プロジェクトストア)

プロジェクトごとの永続的なストアを表します。

| フィールド | 型 | 説明 | 必須 | 検証 |
|------------|----|------|------|------|
| `root_path` | `string` | プロジェクトルートの絶対パス | はい | 有効なディレクトリ |
| `annotations` | `table` | Annotation ID -> Annotation のマップ | はい | なし |
| `version` | `string` | スキーマバージョン | はい | semver |

## 関係

*   **ProjectStore** 1 : N **Annotation** (IDでキー設定)
*   **Annotation** は論理的にプロジェクト内のファイルパスに関連付けられます。

## 状態管理

*   **インメモリ**: グローバルLuaテーブル `_G.marginalia_state` (または `store.lua` のモジュールローカル) が現在のセッションデータを保持します。
*   **永続化**: `VimLeave` または明示的な保存時に、`stdpath('data')/marginalia/{project_hash}.json` にJSONとしてシリアライズされます。
*   **読み込み**: `VimEnter` または初回アクセス時に、JSONから遅延読み込みされます。
