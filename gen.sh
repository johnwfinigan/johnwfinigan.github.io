#!/bin/sh 

set -eu


t1=$(mktemp)
t2=$(mktemp)
mkdir -p dst


#
# content pages generation
# 
for md in src/*.md ; do 

  # convert md to html
  # replace body tag with custom header for css
  # delete last 2 lines (/body /html) for custom footer
  lowdown -s "$md" | \
    perl -pe 's/^<body>$/`cat src\/header`/e' | \
    sed '$d' | sed '$d' > "$t1"

  # create html filename, append source page and footer
  htm=$(basename "$md" .md).html
  cat "$t1" src/footer > "dst/${htm}"


  # create input for index generator
  # index input is markdown format
  day=$(lowdown -X date "$md")
  title=$(lowdown -X title "$md")
  printf "* %s: [%s](%s)\n" "$day" "$title" "${htm}" >> "$t2"

done


#
# index page generation
#
cat <<HERE > "$t1"
title: Index
css: simple.css

HERE

# sort index entries by date
sort -r -k1 -t: "$t2" >> "$t1"

# make html index page
lowdown -s "$t1" | \
  perl -pe 's/^<body>$/`cat src\/header`/e' | \
  sed '$d' | sed '$d' > "$t2"
cat "$t2" src/footer > "dst/index.html"



rm -f "$t1" "$t2"

cp dst/*.html .
