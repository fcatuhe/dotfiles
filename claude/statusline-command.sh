#!/bin/bash
input=$(cat)

dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.current_usage | .input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
total=$(echo "$input" | jq -r '.context_window.context_window_size')
pct=$((used * 100 / total))

branch=$(git -C "$dir" branch --show-current 2>/dev/null)

printf '\033[36m%s\033[0m' "$(basename "$dir")"
if [ -n "$branch" ]; then
  printf ' \033[1;34mgit:(\033[31m%s\033[34m)\033[0m' "$branch"
  git -C "$dir" diff --quiet 2>/dev/null || printf ' \033[33m✗\033[0m'
fi
printf ' \033[35m%s\033[0m \033[90m%s%%\033[0m' "$model" "$pct"
