#!/usr/bin/env bash

if [ $# -lt 2 ]; then
	echo "useage: $0 <SRC> <DEST> [exclude1 exclude2 ...]"
	exit 1
fi

echo "Starting rsync from Obsidian to Hugo..."

SRC="$1"
DEST="$2"
shift 2
echo "Source: $SRC"
echo "Destination: $DEST"

# 排除文件夹
EXCLUDE_PARAMS=""
for item in "$@"; do
    EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude=$item"
done
echo "Excluding patterns: $EXCLUDE_PARAMS"

# 同步文件夹
rsync -av --delete $EXCLUDE_PARAMS "$SRC/" "$DEST/" || { echo "rsync failed"; exit 1; }
echo "rsync completed."

echo ""

echo "Starting Convert $DEST to Hugo format..."

# 非0状态退出,引用未定义变量报错,管道失败报错
set -euo pipefail

cd "$DEST" || { echo "Failed to change directory to $DEST"; exit 1; }

# 避免 *.md 在没有匹配时变成字面字符串
shopt -s nullglob

echo "Converting markdown structure under: $DEST"
echo ""

# 用 find 找出 DEST 下所有目录（包括 . 本身），递归处理
# -print0 + read -d '' 能正确处理中文和空格路径
find . -type d -print0 | while IFS= read -r -d '' section_dir; do
    echo "Processing directory: $section_dir"

    # 在每个目录中处理 *.md（但忽略 _index.md）
    for md_path in "$section_dir"/*.md; do
        # 如果当前目录没有 *.md，这个 for 会直接跳过
        [ -e "$md_path" ] || continue

        md_file="$(basename "$md_path")"
        [ "$md_file" = "_index.md" ] && continue

        name="${md_file%.md}"

        echo "  Converting $md_path -> $section_dir/$name/index.md"

        # 创建新目录，例如 ./其它/hugo/Hugo_Relearn
        mkdir -p "$section_dir/$name"

        # 移动并改名为 index.md
        mv "$md_path" "$section_dir/$name/index.md"

        # 如果存在 assets/<name>，则移动到 <name>/assets/<name>
        if [ -d "$section_dir/assets/$name" ]; then
            echo "  Moving $section_dir/assets/$name -> $section_dir/$name/assets/$name"
            mkdir -p "$section_dir/$name/assets"
            mv "$section_dir/assets/$name" "$section_dir/$name/assets/"
        fi
    done
done

echo ""
echo "Cleaning up empty assets directories..."
find . -type d -name assets -empty -print -delete
echo "Cleanup completed."
echo "Conversion to Hugo format completed."




