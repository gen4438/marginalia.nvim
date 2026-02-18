#!/usr/bin/env bash
# speckit-language-requirement.sh
#
# spec-kit の各コマンド定義ファイル (.md) の "## User Input" 直前に
# "## Language Requirement" セクションを挿入する。

set -euo pipefail

BLOCK='## Language Requirement

**ALL outputs MUST be in Japanese.**

'

DIRS=(
  ".github/agents"
  ".claude/commands"
  ".agent/workflows"
)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

modified=0
skipped=0

for dir in "${DIRS[@]}"; do
  target="${ROOT}/${dir}"
  if [[ ! -d "$target" ]]; then
    echo "SKIP: directory not found: ${dir}"
    continue
  fi

  for file in "${target}"/speckit.*.md; do
    [[ -f "$file" ]] || continue

    # 冪等チェック: 既に含まれていればスキップ
    if grep -qF '## Language Requirement' "$file"; then
      skipped=$((skipped + 1))
      continue
    fi

    # "## User Input" の行番号を取得
    line=$(grep -n '^## User Input' "$file" | head -1 | cut -d: -f1)
    if [[ -z "$line" ]]; then
      echo "WARN: '## User Input' not found in ${file#"$ROOT"/}"
      continue
    fi

    # 挿入: "## User Input" の直前に Language Requirement ブロックを挿入
    {
      head -n $((line - 1)) "$file"
      printf '%s' "$BLOCK"
      tail -n +"$line" "$file"
    } > "${file}.tmp"
    mv "${file}.tmp" "$file"
    modified=$((modified + 1))
    echo "  OK: ${file#"$ROOT"/}"
  done
done

echo ""
echo "Done: ${modified} file(s) modified, ${skipped} file(s) already patched."
