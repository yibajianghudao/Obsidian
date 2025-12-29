#!/usr/bin/env bash
set -euo pipefail

# ---------- 核心：fragment 规范化函数 ----------
normalize_fragment() {
    local frag="$1"

    # 1. 转小写
    frag=$(echo "$frag" | tr '[:upper:]' '[:lower:]')

    # 2. 把 %20 转为普通空格
    frag=$(echo "$frag" | sed 's/%20/ /g')

    # 3. 去除干扰字符
    frag=$(echo "$frag" | sed -E 's/[.,\\()]//g' | sed -E 's/\[//g' | sed -E 's/\]//g' | sed -E "s/[']//g"| sed -E 's/["]//g')

    # 4. 删除 2 个及以上连续的原生 -（直接删掉，不留任何占位）
    frag=$(echo "$frag" | sed -E 's/-{2,}//g')

    # 5. 将所有剩余的空格替换为单个 -
    # frag=$(echo "$frag" | sed -E 's/[[:space:]]+/-/g')
    frag=$(echo "$frag" | sed -E 's/[[:space:]]/-/g')
       
    # # 5. 防止空
    # [ -z "$frag" ] && frag="section"
    
    echo "$frag"
}

# ---------- 处理文件 ----------
process_file() {
    local file="$1"
    echo "========================================"
    echo "Modifying file: $file"
    echo "----------------------------------------"

    # 快速检查是否可能包含需要处理的链接
    if ! grep -qE '\.md#' "$file"; then
        echo "  No internal heading links found."
        echo
        return
    fi

    # 提取所有符合 [文本](路径.md#fragment) 形式的链接
    # grep -oE '\[[^]]*\]\(([^[:space:]]+\.md)#([^)]+)\)' "$file" |
    # grep -oE '\[[^\]]*\]\([^\.]*\.md#(?:[^()]|\([^()]*\)|\((?:[^()]+|\([^()]*\))*\))*[^()]*\)' "$file" |
    perl -nE '
        while (/\[([^\]]*)\]\(((?:[^().]|\([^()]*\))*)\.md#((?:[^()]++|\([^()]*\)|(?:\((?:[^()]+|\([^()]*\))*\)))*[^()]*)\)/g) {
            print "[$1]($2.md#$3)\n";
        }
    ' "$file" |
    while IFS= read -r match; do
        # 使用 bash 正则精确解析（更安全可靠）
        # if [[ $match =~ "\[([^]]+)\]\((([^[:space:]]+\.md))#([^)]+)\)" ]]; then
        if [[ $match =~ "\[(?:[^\[\]]|\[[^\[\]]*\])*\]\([^\.]*\.md#(?:[^()]|\([^()]*\)|\((?:[^()]+|\([^()]*\))*\))*[^()]*\)" ]]; then
            link_text="${BASH_REMATCH[1]}"   # 链接显示文字，如 "安装 过程"
            path="${BASH_REMATCH[3]}"         # 路径，如 "Link.md" 或 "虚拟机/Docker.md"
            old_frag="${BASH_REMATCH[4]}"     # 原始 fragment，如 "安装%20过程" 或 "CentOS7"
            
            new_frag=$(normalize_fragment "$old_frag")

            echo "Found link: [$link_text]($path#$old_frag)"
            echo "  → Changed to: [$link_text]($path#$new_frag)"

            if [[ "$old_frag" != "$new_frag" ]]; then
                echo "  → *** MODIFIED ***"

                # 完整旧链接和新链接（包含 [text](path#frag)）
                old_full="[$link_text]($path#$old_frag)"
                new_full="[$link_text]($path#$new_frag)"

                # 使用 perl 替换，\Q 自动转义所有特殊字符，用 | 作为分隔符避免 / 冲突
                perl -i -pe "s|\\Q$old_full|$new_full|g" "$file"
            else
                echo "  → Already good"
            fi
            echo
        else
            # 理论上不会走到这里，但保留以防万一
            echo "  Skipped unmatched pattern: $match"
            echo
        fi
    done
}
# ---------- 主入口 ----------
if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_or_directory>"
    exit 1
fi

target="$1"

if [ -f "$target" ]; then
    process_file "$target"
elif [ -d "$target" ]; then
    echo "Scanning all index.md in directory..."
    find "$target" -type f -name "index.md" -print0 | while IFS= read -r -d '' f; do
        process_file "$f"
    done
else
    echo "Error: $target not found"
    exit 1
fi

echo "========================================"
echo "Test completed."
