#!/usr/bin/env bash
set -euo pipefail

process_file() {
	local file=$1;
	echo "process file: $file."

	if ! grep -qE '\.md' "$file"; then
		echo "this file dont't have '.md' content. skip this file"
		echo
		return
	fi


}
