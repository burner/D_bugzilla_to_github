#!/usr/bin/bash

curl -s https://issues.dlang.org/rest/bug/$1/comment | jq > issues/bug$1_comments.json
