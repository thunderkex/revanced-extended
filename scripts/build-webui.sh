#!/bin/bash
set -e

echo "Building KernelSU WebUI..."
cd webui
if command -v npm &> /dev/null; then
    npm install --silent
    npm run build
    echo "WebUI build complete. Dist ready in webui/dist"
else
    echo "npm not found, creating static fallback distribution"
    mkdir -p dist
    cp -r index.html dist/ 2>/dev/null || :
fi
