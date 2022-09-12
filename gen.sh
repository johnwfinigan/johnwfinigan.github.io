#!/bin/sh

set -eu

temp_html=$(mktemp)
temp_index=$(mktemp)
temp_index_md=$(mktemp)
temp_index_sorted=$(mktemp)
temp_sitemap=$(mktemp)
mkdir -p dst

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
sort -r -k1 -t^ "$temp_index" >"$temp_index_sorted"
# create markdown from sorted index
awk -F^ '{ printf "* %s: [%s](%s)\n", $1, $2, $3 }' <"$temp_index_sorted" >>"$temp_index_md"

# make html index page
lowdown -s "$temp_index_md" |
  perl -pe 's/^<body>$/`cat src\/header`/e' |
  sed '$d' | sed '$d' >"$temp_html"
cat "$temp_html" src/footer >"dst/index.html"

#
# site map generation
#
cat src/sitemapheader >"$temp_sitemap"
siteurl="$(head -n1 src/siteurl)"
awk -F^ -v site="$siteurl" '{ printf "  <url>\n    <loc>%s%s</loc>\n  </url>\n", site, $3 }' <"$temp_index_sorted" >>"$temp_sitemap"
echo '</urlset>' >>"$temp_sitemap"
cat "$temp_sitemap" >sitemap.xml

#
# cleanup and deploy
#
rm -f "$temp_index_md" "$temp_index" "$temp_index_sorted" "$temp_html" "$temp_sitemap"
cp dst/*.html .
