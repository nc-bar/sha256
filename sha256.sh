#!/bin/bash

cat $1 | head -c -1 | openssl dgst -sha256 | tail -c +10
