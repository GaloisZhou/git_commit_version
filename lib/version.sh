#!/usr/bin/env bash
# .version format: yyyyMMdd.HHmmss.sequence_no
# sequence_no increments globally and never resets

version_parse_sequence() {
  local content="${1:-}"
  content="$(printf '%s' "$content" | tr -d '[:space:]')"
  if [[ "$content" =~ ^[0-9]{8}\.[0-9]{6}\.([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  echo "-1"
}

version_max_sequence() {
  local max=-1
  local seq
  for content in "$@"; do
    [ -z "$content" ] && continue
    seq="$(version_parse_sequence "$content")"
    if [[ "$seq" =~ ^[0-9]+$ ]] && [ "$seq" -gt "$max" ]; then
      max="$seq"
    fi
  done
  echo "$max"
}

version_read_from_ref() {
  local ref="$1"
  git show "${ref}:.version" 2>/dev/null | tr -d '[:space:]' || true
}

version_read_from_file() {
  if [ -f .version ]; then
    tr -d '[:space:]' < .version
  fi
}

version_compute_next() {
  local max
  max="$(version_max_sequence "$@")"
  local next_seq=$((max + 1))
  local timestamp
  timestamp="$(date +"%Y%m%d.%H%M%S")"
  echo "${timestamp}.${next_seq}"
}
