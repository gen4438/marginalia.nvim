# Lua API 契約

## `marginalia` (メインモジュール)

### `setup(opts)`
ユーザー設定でプラグインを初期化します。

*   `opts`: `table` (オプション)
    *   `include_code_block`: `boolean` (デフォルト: `true`)
    *   `auto_copy_to_clipboard`: `boolean` (デフォルト: `false`)
    *   `project_root_markers`: `table` (文字列のリスト, デフォルト: `['.git']`)
    *   `persistence`: `boolean` (デフォルト: `true`)

**例:**
```lua
require('marginalia').setup({
  include_code_block = true,
  auto_copy_to_clipboard = true
})
```

## `marginalia.core.capture` (内部)

### `process_selection(bufnr, start_line, end_line, comment)`
選択範囲とコメントを受け取り、以下を実行します:
1.  `Annotation` オブジェクトを作成します。
2.  `store` 経由で永続化します。
3.  `generate` を呼び出して出力をフォーマットします。
4.  オプションでクリップボードにコピーします。

*   `bufnr`: `number` (バッファID)
*   `start_line`: `number` (1-based)
*   `end_line`: `number` (1-based)
*   `comment`: `string`

## `marginalia.core.store` (内部)

### `add_annotation(annotation)`
注釈を現在のプロジェクトのストアに追加します。

### `get_annotations(project_root)`
指定されたプロジェクトルートのすべての注釈リストを返します。

### `remove_annotation(id)`
IDで注釈を削除します。

### `save()`
現在の状態をディスクに保存します。

### `load()`
現在のプロジェクトの状態をディスクから読み込みます。

## `marginalia.ui.display`

### `open_list()`
すべての注釈をQuickfixリストに入力し、Quickfixウィンドウを開きます。

### `copy_last()`
最後に生成されたMarkdownをクリップボードにコピーします。

## `marginalia.ui.input` (新規)

### `open_floating_input(on_confirm)`
入力用のフローティングウィンドウを開きます。 `<Esc>` で通常の入力モード終了、`:w` で確定、`:q!` または何も入力せず閉じることでキャンセル。

*   `on_confirm`: `function(text)` コールバック。
