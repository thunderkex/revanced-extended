#!/bin/bash
set -e

echo "Deploying pages from docs/..."
git checkout gh-pages 2>/dev/null || git checkout -b gh-pages
cp -r docs/* .
git add -A
git commit -m "deploy: update GitHub Pages site" || :
git push origin gh-pages --force || :
echo "Deployment triggered."
