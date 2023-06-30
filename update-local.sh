#!/bin/sh 

set -eux

sitepath=/var/www/htdocs/site/

install -m0644 simple.css $sitepath
install -m0644 atom.xml $sitepath

for h in dst/*.html ; do
  install -m0644 "$h" $sitepath
done
