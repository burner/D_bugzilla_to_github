#!/usr/bin/env bash

# Use this one-liner to produce a JSON literal from the Git log:

git log \
    --pretty=format:'{%n  "commit": "%H",%n  "authorEmail": "%aE",%n  "authorName": "%aN",%n  "date": "%aI"%n},' \
    $@ | \
    perl -pe 'BEGIN{print "["}; END{print "]\n"}' | \
    perl -pe 's/},]/}]/'
