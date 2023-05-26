#!/bin/ksh

# Copyright (c) 2021-2023 John Finigan
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -eu

temp_html=$(mktemp)
temp_index=$(mktemp)
temp_index_md=$(mktemp)
temp_index_sorted=$(mktemp)
temp_sitemap=$(mktemp)
temp_atom=$(mktemp)
mkdir -p dst
rm -f dst/*.html

#
# content pages generation
#
for md in src/*.md; do
  # convert md to html
  # replace body tag with custom header for css
  # delete last 2 lines (/body /html) for custom footer
  lowdown -s "$md" |
    perl -pe 's/^<body>$/`cat src\/header`/e' |
    sed '$d' | sed '$d' >"$temp_html"

  # create html filename, append source page and footer
  htm=$(basename "$md" .md).html
  cat "$temp_html" src/footer >"dst/${htm}"

  # create input for index generator
  day=$(lowdown -X date "$md")
  title=$(lowdown -X title "$md")
  printf "%s^%s^%s\n" "$day" "$title" "${htm}" >>"$temp_index"
done

#
# index page generation
#
cat <<HERE >"$temp_index_md"
title: Index
css: simple.css

HERE

# sort index entries by date
# output format is date^title^filename
sort -r -k1 -t^ "$temp_index" >"$temp_index_sorted"
# create markdown from sorted index
awk -F^ '{ printf "* %s: [%s](%s)\n", $1, $2, $3 }' <"$temp_index_sorted" >>"$temp_index_md"

# make html index page
lowdown -s "$temp_index_md" |
  perl -pe 's/^<body>$/`cat src\/header`/e' |
  sed '$d' | sed '$d' >"$temp_html"
cat "$temp_html" src/footer >"dst/index.html"


siteurl="$(head -n1 src/siteurl)"

#
# site map generation
#
cat <<'HERE' >"$temp_sitemap"
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
HERE
awk -F^ -v site="$siteurl" '{ printf "  <url>\n    <loc>%s%s</loc>\n  </url>\n", site, $3 }' <"$temp_index_sorted" >>"$temp_sitemap"
echo '</urlset>' >>"$temp_sitemap"
cat "$temp_sitemap" >sitemap.xml


#
# atom feed generation
#
cat <<'HERE' > "$temp_atom"
<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">

  <title>johnwfinigan.github.io</title>
  <link rel="self" type="application/atom+xml" href="https://johnwfinigan.github.io/atom.xml"/>
HERE

awk -F^ '{printf "  <updated>%sT00:00:00Z</updated>\n", $1; exit}' < "$temp_index_sorted" >> "$temp_atom"

cat <<'HERE' >> "$temp_atom"
  <author>
    <name>John Finigan</name>
  </author>
  <id>tag:johnwfinigan.github.io,2015-09-14:blog</id>
  <rights> Copyright 2015-2023 John Finigan </rights>
HERE

while IFS='^' read -r entrydate title filename; do
  entryname="${filename%%.html}"
  # shellcheck disable=SC2129
  printf '<entry>\n' >> "$temp_atom"
  printf '<id>tag:johnwfinigan.github.io,%s:%s</id>\n' "$entrydate" "$entryname" >> "$temp_atom"
  printf '<title>%s</title>\n' "$title" >> "$temp_atom"
  printf '<updated>%sT00:00:00Z</updated>\n' "$entrydate" >> "$temp_atom"
  printf '<author> <name>John Finigan</name> </author>\n' >> "$temp_atom"
  printf '<content>\n' >> "$temp_atom"
  lowdown -tman "src/${entryname}.md" | mandoc | col -b |
    sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' |
    sed '1d' | sed '$d' >> "$temp_atom"
  printf '</content></entry>\n' >> "$temp_atom"
done < "$temp_index_sorted"
printf '</feed>\n' >> "$temp_atom"
cat "$temp_atom" > atom.xml


#
# cleanup and deploy
#
rm -f "$temp_index_md" "$temp_index" "$temp_index_sorted" "$temp_html" "$temp_sitemap" "$temp_atom"
cp dst/*.html .

# date -u '+%Y-%m-%dT%H:%M:%SZ'
