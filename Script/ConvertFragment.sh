#!/bin/bash
set -euo pipefail

ConvertFragToHugo() {
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
    frag=$(echo "$frag" | sed -E 's/[[:space:]]/-/g')
       
    echo "$frag"
}

process_file() {
	local file=$1;
	echo "process file: $file."

	if ! grep -qE '\.md' "$file"; then
		echo "this file dont't have '.md' content. skip this file"
		echo
		return
	fi

    # 正则表达式是`\[(?:[^\[\]]|\[[^\[\]]*\])*\]\([^\.]*\.md#(?:[^()]|\([^()]*\)|\((?:[^()]+|\([^()]*\))*\))*[^()]*\)`,下面的while因为分组所以进行了一些改变
    perl -nE '
    while (/\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(([^\.]*).md#((?:[^()]|\([^()]*\)|\((?:[^()]+|\([^()]*\))*\))*[^()]*)\)/g) {
        print "$1\t$2\t$3\n";
    }
    ' "$file" |
    while IFS=$'\t' read -r text link old_frag; do
        new_frag=$(ConvertFragToHugo "$old_frag")
        old_full="[$text]($link.md#$old_frag)"

        if [[ $old_frag != $new_frag ]]; then 
            new_full="[$text]($link.md#$new_frag)"

            echo "--------------------"
            echo "found link: $old_full"
            echo "Converted Frag: $new_full"
            
            perl -i -pe "s|\\Q$old_full|$new_full|g" "$file"

        else
            echo "$old_full don't need convert."
        fi

    done
}

if [[ $# -eq 0 ]]; then
	echo "isn't given any arguments;"
	exit 1
fi

target="$1"

if [[ -f "$target" ]]; then
	process_file "$target"
elif [[ -d "$target" ]]; then
    echo "Scanning all index.md in directory..."
    find "$target" -type f -name "index.md" -print0 | while IFS= read -r -d '' f; do
        process_file "$f"
    done
else
    echo "Error: $target not found."
    exit 1
fi

echo "=================="
echo "Converte Formot Success."
