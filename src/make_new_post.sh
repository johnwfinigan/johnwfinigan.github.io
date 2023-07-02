#!/bin/sh

filename="$(echo "$@" | sed 's/ /-/g')"
printf 'title: %s\ndate: %s\ncss: style.css\ntags:\n\n\n## %s\n' "$@" "$(date +%Y-%m-%d)" "$@" > "${filename}.md"
vim "${filename}.md"
