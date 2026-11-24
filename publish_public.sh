#!/usr/bin/env bash
set -euo pipefail

# 單向去識別化發布腳本：從主目錄 index.html 產生公開版至 public-pages/
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLIC_DIR="$ROOT_DIR/public-pages"

if [ ! -d "$PUBLIC_DIR/.git" ]; then
  echo "❌ 找不到 $PUBLIC_DIR/.git，請先確認已初始化 public-pages。"
  exit 1
fi

python3 - "$ROOT_DIR/index.html" "$PUBLIC_DIR/index.html" <<'PY'
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as f:
    html = f.read()

replacements = [
    ("👨‍👩‍👧 6 人（父母 80 歲・小孩 8 歲）", "👨‍👩‍👧 6 人（含長輩與兒童）"),
    ("對 80 歲長輩負擔偏大", "對長輩負擔偏大"),
    ("（預約 140819727）", "（已預約）"),
    ("（8 歲可泡）", "（兒童可泡）"),
    ("最適合 80 歲長輩上下車", "最適合長輩上下車"),
    ("小孩 8 歲：法律沒有強制", "兒童安全座椅：6 歲以上法律沒有強制"),
    ("星宇 DUD2RL｜", "星宇｜"),
    ("兒童增高座墊（8 歲）", "兒童增高座墊"),
    ("預約號碼 KBPXDX270324｜", ""),
    ("：訂單 5055944392、6687307067", ""),
    ("：預約 KBPXDX270324", ""),
    ("：訂單 5707720472", ""),
    ("（訂單 5055944392、6687307067、5707720472）", ""),
    ("（預約 KBPXDX270324）", ""),
    ("｜1/26 送機 26KK227114722｜1/31 接機 26KK222114132", "｜1/26 送機・1/31 接機（已預約）"),
]

for old, new in replacements:
    html = html.replace(old, new)

# 檢查去除 base64 圖片後是否仍殘留任何敏感關鍵字
text_only = re.sub(r"data:image/[^;]+;base64,[A-Za-z0-9+/=]+", "", html)
forbidden = [
    r"DUD2RL",
    r"140819727",
    r"KBPXDX270324",
    r"5055944392",
    r"6687307067",
    r"5707720472",
    r"26KK227114722",
    r"26KK222114132",
    r"kfz2cl",
    r"8dac197a",
    r"sfchen0816",
    r"80\s*歲",
    r"52\s*歲",
    r"46\s*歲",
    r"8\s*歲",
    r"CHEN",
    r"YEH",
]
hits = []
for pat in forbidden:
    if re.search(pat, text_only, re.IGNORECASE):
        hits.append(pat)

if hits:
    print(f"❌ 偵測到未清除的敏感字詞：{hits}，已中止發布！", file=sys.stderr)
    sys.exit(1)

with open(dst, "w", encoding="utf-8") as f:
    f.write(html)
print(f"✅ 已產生乾淨的公開版：{dst}")
PY

cp "$ROOT_DIR/README.md" "$PUBLIC_DIR/README.md"

cd "$PUBLIC_DIR"
git add index.html README.md
if git diff --cached --quiet; then
  echo "ℹ️ 公開版沒有變更，無需推送。"
else
  MSG="${1:-chore: update sanitized travel guide}"
  git commit -m "$MSG"
  git push origin main
  echo "🚀 已推送至 GitHub Pages (squarec/kyushu-2027-winter)！"
fi
