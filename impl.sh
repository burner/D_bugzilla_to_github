#!/usr/bin/bash

curl -s https://issues.dlang.org/rest/bug/$1 | jq > issues/bug$1.json
