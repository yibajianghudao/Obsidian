#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# 配置区域
# ==========================================

# 日志级别设置
# 0: 仅显示错误 (Error) 和 最终成功提示
# 1: 显示关键步骤 (Info) - 推荐
# 2: 显示详细调试信息 (Debug) - 包括具体的文件移动和处理细节
LOG_LEVEL=1

# Git 仓库路径
GIT_REPO_HUGO="$HOME/Code/HugoBlog"
GIT_REPO_OBSIDIAN="$HOME/Code/Obsidian"

# ==========================================
# 工具函数
# ==========================================
log_error() { echo "[ERROR] $1" >&2; }
log_success() { echo "[SUCCESS] $1"; }

log_info() {
    if [[ $LOG_LEVEL -ge 1 ]]; then
        echo "[INFO] $1"
    fi
}

log_debug() {
    if [[ $LOG_LEVEL -ge 2 ]]; then
        echo "[DEBUG] $1"
    fi
}
# 检查参数
if [ $# -lt 2 ]; then
    log_error "Usage: $0 <SRC> <DEST> [exclude1 exclude2 ...]"
    exit 1
fi

SRC="$1"
DEST="$2"
shift 2

# ==========================================
# 阶段一：同步与结构重组 (原 ConvertObsidianToHugo)
# ==========================================

log_info "Step 1/4: Syncing files from Obsidian to Hugo..."
log_debug "Source: $SRC"
log_debug "Destination: $DEST"

# 构造排除参数
EXCLUDE_PARAMS=""
for item in "$@"; do
    EXCLUDE_PARAMS="$EXCLUDE_PARAMS --exclude=$item"
done
log_debug "Excluding: $EXCLUDE_PARAMS"

# rsync 同步
# 如果不是 debug 模式，稍微抑制一下 rsync 的输出
RSYNC_OPTS="-av --delete"
if [[ $LOG_LEVEL -lt 2 ]]; then
    RSYNC_OPTS="-a --delete" 
fi

rsync $RSYNC_OPTS $EXCLUDE_PARAMS "$SRC/" "$DEST/" || { log_error "rsync failed"; exit 1; }

log_info "Step 2/4: Converting folder structure to Hugo Page Bundles..."

cd "$DEST" || { log_error "Failed to enter directory $DEST"; exit 1; }
shopt -s nullglob

# 递归处理目录结构
find . -type d -print0 | while IFS= read -r -d '' section_dir; do
    # 处理 *.md (忽略 _index.md)
    for md_path in "$section_dir"/*.md; do
        [ -e "$md_path" ] || continue
        md_file="$(basename "$md_path")"
        [ "$md_file" = "_index.md" ] && continue

        name="${md_file%.md}"
        
        # 创建 Page Bundle 目录
        mkdir -p "$section_dir/$name"
        
        # 移动并重命名
        mv "$md_path" "$section_dir/$name/index.md"
        log_debug "Converted: $md_path -> $section_dir/$name/index.md"

        # 处理资源文件夹
        if [ -d "$section_dir/assets/$name" ]; then
            mkdir -p "$section_dir/$name/assets"
            mv "$section_dir/assets/$name" "$section_dir/$name/assets/"
            log_debug "Moved Assets: $section_dir/assets/$name -> $section_dir/$name/assets/"
        fi
    done
done

# 清理空资源目录
find . -type d -name assets -empty -delete
log_debug "Cleaned up empty assets directories."

# ==========================================
# 阶段二：处理 Fragment 锚点 (原 ConvertFragment)
# ==========================================

log_info "Step 3/4: Fixing Fragment Links and Anchors..."

# 内部函数：转换 Fragment 字符串
ConvertFragToHugo() {
    local frag="$1"
    # 1. 转小写
    frag=$(echo "$frag" | tr '[:upper:]' '[:lower:]')
    # 2. %20 -> 空格
    frag=$(echo "$frag" | sed 's/%20/ /g')
    # 3. 去除干扰字符
    frag=$(echo "$frag" | sed -E 's/[.,\\()]//g' | sed -E 's/\[//g' | sed -E 's/\]//g' | sed -E "s/[']//g"| sed -E 's/["]//g')
    # 4. 删除连续 -
    frag=$(echo "$frag" | sed -E 's/-{2,}//g')
    # 5. 空格 -> -
    frag=$(echo "$frag" | sed -E 's/[[:space:]]/-/g')
    echo "$frag"
}

# 内部函数：转换链接路径
ConvertLink() {
    local link=$1
    if [[ $link == *"../"* ]]; then
        link=$(echo "$link" | sed -E 's_../_../../_')
    fi
    echo "$link"
}

# 处理单个文件
process_file() {
    local file=$1;
    local file_changed=false
    
    # 快速检查是否有 .md 链接，没有则跳过正则匹配以节省时间
    if ! grep -qE '\.md' "$file"; then
        log_debug "$file dont't have '.md' content. skip this file"
        return
    fi

    # Perl 正则逻辑保持不变
    perl -nE '
    while (/\[((?:[^\[\]]|\[[^\[\]]*\])*)\]\(([^)]*).md#?((?:[^()]|\([^()]*\)|\((?:[^()]+|\([^()]*\))*\))*[^()]*)\)/g) {
        print "$1\t$2\t$3\n";
    }
    ' "$file" |
    while IFS=$'\t' read -r text link old_frag; do
        new_frag=$(ConvertFragToHugo "$old_frag")
        new_link=$(ConvertLink "$link")
        old_full="[$text]($link.md#$old_frag)"

        if [[ $old_frag != $new_frag || $link != $new_link ]]; then 
            new_full="[$text]($new_link.md#$new_frag)"
            
            # 执行替换
            perl -i -pe "s|\\Q$old_full|$new_full|g" "$file"
            
            log_debug "Fixed link in $(basename "$file"): \n   From: $old_full\n   To:   $new_full"
            file_changed=true
        fi
    done

    if [[ "$file_changed" == "true" ]]; then
        log_info "Updated links in: $file"
    fi
}

# 导出函数供子 shell 使用 (如果有必要，但在当前循环逻辑下直接调用即可)
export -f ConvertFragToHugo
export -f ConvertLink
export -f process_file
export LOG_LEVEL
export RED GREEN YELLOW BLUE NC

# 扫描 DEST 目录下的所有 index.md
# 使用 while loop 而不是 -exec，方便我们在内部调用 bash 函数并控制日志
find "$DEST" -type f -name "index.md" -print0 | while IFS= read -r -d '' f; do
    process_file "$f"
done

# ==========================================
# 阶段三：Git 部署 (逻辑已更新)
# ==========================================

log_info "Step 4/4: Preparing for Git deployment..."

# 恢复标准输入（防止之前的管道影响 read 命令）
exec < /dev/tty

echo ""
echo "------------------------------------------------"
# 修改了提示语：明确这里只是开始 add/commit
read -p "Do you want to start Git processing (add & commit) for both repos? [y/N] " confirm
echo ""

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    
    # 获取 Commit 信息
    read -p "Enter commit message (Press Enter for default: 'some update'): " input_msg
    commit_msg="${input_msg:-some update}"
    echo "Using commit message: '$commit_msg'"
    echo "------------------------------------------------"

    # 定义要处理的仓库数组
    repos=("$GIT_REPO_OBSIDIAN" "$GIT_REPO_HUGO")

    for repo in "${repos[@]}"; do
        if [ -d "$repo" ]; then
            repo_name=$(basename "$repo")
            log_info "Processing repository: $repo_name"
            
            # 进入目录
            cd "$repo" || { log_error "Cannot enter $repo"; continue; }

            # 检查是否有变动
            if [[ -z $(git status --porcelain) ]]; then
                log_info "No changes detected in $repo_name. Skipping."
            else
                # 1. 总是执行 add 和 commit
                git add .
                git commit -m "$commit_msg"
                log_success "Changes committed locally for $repo_name."

                # 2. 二次确认：是否 Push
                # 使用 /dev/tty 确保在循环中也能读取输入
                echo -n "   > Ready to PUSH $repo_name to origin main? [y/N] "
                read confirm_push < /dev/tty

                if [[ "$confirm_push" =~ ^[Yy]$ ]]; then
                    log_info "Pushing to origin main..."
                    git push origin main || log_error "Push failed for $repo_name"
                    log_success "Deployment (Push) completed for $repo_name."
                else
                    # 按照要求：不通过则结束（只保留了 add/commit 的状态）
                    log_info "Push skipped. (Changes remain committed locally)"
                fi
            fi
            echo "------------------------------------------------"
        else
            log_error "Repository path not found: $repo"
        fi
    done

else
    log_info "Git deployment skipped by user."
fi

# ==========================================
# 结束
# ==========================================
echo ""
log_success "All scripts finished."
