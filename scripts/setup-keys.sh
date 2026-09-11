#!/bin/bash
set -e

KEYS_DIR="./keys"
MODULE_KEYSTORE="$KEYS_DIR/module.jks"
APK_KEYSTORE="$KEYS_DIR/apk.jks"

mkdir -p "$KEYS_DIR"

if [ -f .env ]; then
    source .env
fi

MODULE_KEYSTORE_PASSWORD=${MODULE_KEYSTORE_PASSWORD:-"defaultpassword123"}
MODULE_KEY_ALIAS=${MODULE_KEY_ALIAS:-"rvx"}
APK_KEYSTORE_PASSWORD=${APK_KEYSTORE_PASSWORD:-"defaultpassword123"}
APK_KEY_ALIAS=${APK_KEY_ALIAS:-"rvx"}

if ! command -v keytool &> /dev/null; then
    echo "keytool not found. Please install Java JDK first."
    exit 1
fi

if [ ! -f "$MODULE_KEYSTORE" ]; then
    echo "Generating module signing keystore..."
    keytool -genkeypair \
        -alias "$MODULE_KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -keystore "$MODULE_KEYSTORE" \
        -storepass "$MODULE_KEYSTORE_PASSWORD" \
        -keypass "$MODULE_KEYSTORE_PASSWORD" \
        -dname "CN=Revanced Extended, OU=Ministry of Silly Builds, O=Thunderkex, L=CyberSpace, ST=Somewhere Over The Galaxy, C=XX" \
        -storetype JKS
    echo "Module keystore created: $MODULE_KEYSTORE"
else
    echo "Module keystore already exists: $MODULE_KEYSTORE"
fi

if [ ! -f "$APK_KEYSTORE" ]; then
    echo "Generating APK signing keystore..."
    keytool -genkeypair \
        -alias "$APK_KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -keystore "$APK_KEYSTORE" \
        -storepass "$APK_KEYSTORE_PASSWORD" \
        -keypass "$APK_KEYSTORE_PASSWORD" \
        -dname "CN=Revanced Extended, OU=Ministry of Silly Builds, O=Thunderkex, L=CyberSpace, ST=Somewhere Over The Galaxy, C=XX" \
        -storetype JKS
    echo "APK keystore created: $APK_KEYSTORE"
else
    echo "APK keystore already exists: $APK_KEYSTORE"
fi

if ! grep -q "keys/" .gitignore 2>/dev/null; then
    echo "keys/" >> .gitignore
    echo "*.jks" >> .gitignore
fi
