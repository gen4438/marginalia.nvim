# Feature Specification: Core Features
# marginalia.nvim: Code Selection, Annotation, and Prompt Generation

**Feature Branch**: `001-core-features`
**Created**: 2026-02-19
**Status**: Draft
**Input**: User description: "Implement core functionality based on `proposal.md`"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Select Code & Annotate (Priority: P1)

ユーザーは、Visual Modeで選択したコードブロックに対して、エディタを離れることなく注釈（コメント）を入力できる。

**Why this priority**: これは本プラグインの最も基本的かつ核となるインタラクションであり、これなしでは他の機能が存在し得ないため。

**Independent Test**:
1. Neovimでファイルを一意に識別できる行を選択する。
2. プラグインのコマンドを実行する。
3. 入力ポップアップが表示されることを確認する。
4. 入力したテキストが正しくキャプチャされることをログ等で確認する。

**Acceptance Scenarios**:

1. **Given** 任意のテキストファイルを開いている, **When** Visual Modeで行を選択しコマンド実行, **Then** 入力プロンプトが表示される。
2. **Given** 入力プロンプトが表示中, **When** テキストを入力しEnter押下, **Then** 入力が確定され、内部データとして保持される。
3. **Given** 入力プロンプトが表示中, **When** Escまたは空入力でキャンセル, **Then** 処理が中止され、何も生成されない。

---

### User Story 2 - Generate Formatted Context (Priority: P2)

ユーザーのコメントと選択されたコードブロックを結合し、AIへの指示に適したMarkdown形式のテキストを生成する。このデータはプラグイン内部で保持され、履歴として利用可能になる。

**Why this priority**: 注釈とコードを統合したテキスト生成は本プラグインの主要な出力であり、履歴機能や表示機能の基盤となるため。

**Independent Test**:
1. モックデータ（ファイルパス、行番号、コード、コメント）を用意する。
2. フォーマット関数を実行する。
3. 生成された文字列が期待されるMarkdown構造であることを検証する。

**Acceptance Scenarios**:

1. **Given** コード選択とコメント入力が完了, **When** 生成処理が実行される, **And** オプション `include_code_block` が `true` (デフォルト), **Then** 以下の情報を含むテキストが生成される: ファイルパス、行番号範囲、言語識別子付きコードブロック、区切り線、ユーザーコメント。
2. **Given** コード選択とコメント入力が完了, **When** 生成処理が実行される, **And** オプション `include_code_block` が `false`, **Then** 以下の情報を含むテキストが生成される: ファイルパス、行番号範囲、区切り線、ユーザーコメント (コードブロックは含まれない)。
3. **Given** 生成完了, **Then** 生成されたデータが内部ストアに保存される。

---

### User Story 3 - Project-based Review (Quickfix) (Priority: P3)

ユーザーは現在のプロジェクト（デフォルト: `.git` リポジトリ）内の全注釈をQuickfix Listで一覧表示し、該当箇所へジャンプできる。

**Why this priority**: 作業中に過去のコンテキストへ素早くアクセスするため。

**Independent Test**:
1. 異なるファイルで複数の注釈を作成する。
2. Quickfix表示コマンドを実行する。
3. Quickfix Listが開き、すべての注釈が含まれていることを確認する。
4. リストの項目を選択し、該当ファイルの該当行へジャンプすることを確認する。

**Acceptance Scenarios**:
1. **Given** プロジェクト内に複数の注釈が存在, **When** Quickfix表示コマンド実行, **Then** プロジェクトルート（`.git`等で判定）内の注釈がQuickfix Listにセットされ、ウィンドウが開く。
2. **Given** 設定 `project_root_markers` が指定されている, **When** コマンド実行, **Then** 指定マーカーを持つディレクトリをルートとして注釈を収集する。

---

### User Story 4 - Comment Management (Buffer) (Priority: P3)

ユーザーは専用のバッファで注釈の一覧（全文など詳細）を確認し、不要な注釈を削除できる。削除操作は即座に反映され、Quickfix Listなどからも取り除かれる。

**Why this priority**: 古くなった注釈や不要なコンテキストを整理し、情報の鮮度を保つため。

**Independent Test**:
1. 管理バッファ表示コマンドを実行する。
2. 表示されたバッファ内で特定の注釈ブロックを削除し、保存する。
3. 再度Quickfix表示コマンドを実行し、削除した注釈が存在しないことを確認する。

**Acceptance Scenarios**:
1. **Given** プロジェクト内に複数の注釈が存在, **When** 管理コマンド実行, **Then** 編集可能な専用バッファが開き、注釈の詳細一覧が表示される。
2. **Given** 管理バッファで注釈を削除して保存, **Then** 内部ストアから該当データが削除される。
3. **Given** 削除完了, **Then** Quickfix Listが更新され、削除された項目が消失する。

### User Story 5 - Clipboard Integration (Priority: P3)

ユーザーは設定またはコマンドにより、生成されたテキストをVimのクリップボードへコピーできる。

**Why this priority**: 外部のLLMツールへ貼り付けるための機能だが、必須ではなく、内部バッファでの確認だけでも機能は成立するため。

**Independent Test**:
1. コンテキスト生成を実施する。
2. オプション `auto_copy_to_clipboard` を有効にする、またはコピーコマンドを実行する。
3. Vimのクリップボードレジスタ（`*` または `+`）に生成テキストが格納されていることを確認する。

**Acceptance Scenarios**:
1. **Given** 生成完了, **And** オプション `auto_copy_to_clipboard` が `true`, **Then** 生成テキストがVimの `clipboard` 設定に従って自動的にコピーされる。
2. **Given** 生成完了, **And** オプション `auto_copy_to_clipboard` が `false`, **Then** 自動コピーは行われない。
3. **Given** 注釈一覧バッファ, **When** コピー操作を実行, **Then** 選択した注釈（またはそのコンテキスト）がクリップボードにコピーされる。

---

### Edge Cases

- **空選択**: Visual Modeで何も選択せずにコマンドを実行した場合、現在行を対象とするか、エラーを表示するか（デフォルト：エラーまたは現在行）。
- **巨大なファイル/選択**: 非常に長い行数を選択した場合のパフォーマンスと、クリップボード容量の制限。
- **特殊なファイル**: ファイルパスが存在しないバッファ（No Name）や、特殊なバッファタイプ（Terminalなど）での動作。
- **マルチバイト文字**: 日本語コメントや、日本語を含むコードの文字化け防止。

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: システムはVisual Modeでの選択範囲（開始行、終了行）を正確に取得しなければならない。
- **FR-002**: システムは現在のバッファの相対ファイルパスとファイルタイプ（拡張子）を取得しなければならない。
- **FR-003**: システムはFloating Window（ポップアップウィンドウ）を使用して、ユーザーからの複数行のテキスト入力を受け付けなければならない。操作はVimのバッファ操作に準拠する（保存 `:w` で確定、破棄 `:q!` でキャンセル）。
- **FR-004**: システムは取得した情報（メタデータ、コード、コメント）を固定のMarkdownテンプレート（初期バージョンではカスタマイズ不可）に従って整形しなければならない。
- **FR-005**: システムはユーザー設定が有効な場合、整形されたテキストをVimの `clipboard` 設定に従ってレジスタ（`+`, `*`, または無名レジスタ）に書き込まなければならない。
- **FR-006**: システムは外部ランタイムなしで動作しなければならない。
- **FR-007**: システムはユーザー設定により、生成されるテキストにコードブロックを含めるかどうかを制御できなければならない (デフォルト: `true`)。
- **FR-008**: システムは現在のバッファが属するプロジェクトルートを特定しなければならない（デフォルト: `.git` ディレクトリの存在、設定可能）。
- **FR-009**: システムは `stdpath('data')` 配下のファイル（例: JSON形式）に、プロジェクト単位で注釈データを永続化しなければならない。
    - **FR-010**: システムは注釈一覧を表示・編集するための専用バッファを提供する。このバッファはMarkdown形式ですべての注釈（コードとコメント）を完全に展開して表示しなければならない。
    - **FR-011**: システムは一覧バッファでの削除操作（テキストブロックの削除）をバッファ保存時または変更時に検知し、対応する注釈データを内部ストアおよびQuickfix Listから削除しなければならない。
    - **FR-012**: システムはプロジェクト内の注釈一覧を標準のQuickfix Listに設定し、ファイルへのジャンプ機能を提供しなければならない。

### Key Entities

- **AnnotationContext**:
    - `file_path`: String (相対パス)
    - `file_type`: String (拡張子/ft)
    - `start_line`: Integer (1-based)
    - `end_line`: Integer (1-based)
    - `code_content`: String (選択された行の生テキスト)
    - `user_comment`: String (ユーザー入力)
    - `project_root`: String (検出されたプロジェクトルートパス)

- **Config**:
    - `include_code_block`: Boolean (default: `true`)
    - `auto_copy_to_clipboard`: Boolean (default: `false`)
    - `project_root_markers`: List<String> (default: `['.git']`)

## Clarifications

### Session 2026-02-19

- Q: 注釈データ（コメントやメタデータ）の保存場所はどこにしますか？ -> A: **User Data Path**: `stdpath('data')` 内に保存する（推奨）。
- Q: 注釈入力時のUIはどうしますか？ -> A: **Floating Window**: マルチライン入力が可能なポップアップウィンドウを使用する。
- Q: Floating Window内での操作キーマッピングはどうしますか？ -> A: **Vim-like**: バッファとして扱い、`:w` (保存) で確定、`:q!` (破棄) または何もせず閉じることでキャンセルとする。
- Q: 管理バッファ（User Story 4）の表示形式と削除操作の仕様はどうしますか？ -> A: **Full Content Buffer**: 全注釈を展開したMarkdownバッファを表示し、ブロック削除を検知して同期する。
- Q: 生成されるMarkdownの形式は固定ですか？それともユーザー設定可能にしますか？ -> A: **Fixed Template**: 初期バージョンでは固定フォーマットのみ提供し、将来的な拡張とする。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: ユーザーはコード選択からコンテキスト生成までを、キーボード操作のみで完了できる。
- **SC-002**: 生成されたテキストをLLMに貼り付けた際、ファイル名と行番号が認識され、文脈が正しく伝わる。
- **SC-003**: 1000行程度のコード選択であっても、処理が1秒以内に完了し、エディタがフリーズしない。

## Assumptions

- ユーザーはNeovim 0.9.0以上を使用している。
- クリップボード連携機能を使用する場合、ユーザーの環境でVimのクリップボードプロバイダが正しく設定されている。
