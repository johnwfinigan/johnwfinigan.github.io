#!/bin/sh 

set -eux

install -m0644 simple.css /var/www/htdocs/

for h in dst/*.html ; do
  install -m0644 "$h" /var/www/htdocs/
done
