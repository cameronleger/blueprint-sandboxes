#!/usr/bin/env bash

name=$(cat info.json | jq -r .name)
version=$(cat info.json | jq -r .version)

# Create git tag for this version
git tag -f "$version"

# Prepare zip for Factorio native use and mod portal
git archive --prefix "${name}_$version/" \
  -o "${name}_$version.zip" \
  HEAD
