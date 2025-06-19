#!/bin/bash

echo "=== Environment Variable Debug Script ==="
echo "Date: $(date)"
echo ""

echo "=== Checking Jenkins Credentials ==="
echo "DB_HOST: '${DB_HOST}'"
echo "DB_PORT: '${DB_PORT}'"
echo "DB_DATABASE: '${DB_DATABASE}'"
echo "DB_USERNAME: '${DB_USERNAME}'"
echo "DB_PASSWORD: '[MASKED]'"
echo "APP_URL: '${APP_URL}'"
echo ""

echo "=== DB_PORT Validation ==="
if [[ -z "${DB_PORT}" ]]; then
    echo "ERROR: DB_PORT is empty!"
    exit 1
fi

if [[ ! "${DB_PORT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: DB_PORT '${DB_PORT}' is not a valid integer!"
    echo "DB_PORT length: ${#DB_PORT}"
    echo "DB_PORT hex dump:"
    echo "${DB_PORT}" | hexdump -C
    echo "DB_PORT ascii dump:"
    echo "${DB_PORT}" | od -c
    exit 1
fi

echo "DB_PORT validation passed: ${DB_PORT}"
echo ""

echo "=== Testing Groovy String Interpolation ==="
# 模擬 Jenkins pipeline 中的 GString 插值
TEST_YAML="LARAVEL_DATABASE_PORT_NUMBER: ${DB_PORT}"
echo "Generated YAML line: ${TEST_YAML}"

if [[ "${TEST_YAML}" == "LARAVEL_DATABASE_PORT_NUMBER: ${DB_PORT}" ]]; then
    echo "WARNING: Variable interpolation may have failed!"
else
    echo "Variable interpolation appears to be working"
fi
echo ""

echo "=== Testing with explicit integer conversion ==="
DB_PORT_INT=$(echo "${DB_PORT}" | tr -d '[:space:]')
echo "DB_PORT_INT: '${DB_PORT_INT}'"

if [[ ! "${DB_PORT_INT}" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Even after trimming, DB_PORT is not a valid integer!"
    exit 1
fi

echo "DB_PORT_INT validation passed: ${DB_PORT_INT}"
echo ""

echo "=== Testing Kubernetes Secret stringData format ==="
# 模擬正確的 Kubernetes Secret stringData 格式
SECRET_YAML="  LARAVEL_DATABASE_PORT_NUMBER: \"${DB_PORT_INT}\""
echo "Correct Secret YAML format: ${SECRET_YAML}"

# 檢查是否包含引號
if [[ "${SECRET_YAML}" == *'"'* ]]; then
    echo "✅ Secret YAML format is correct (contains quotes)"
else
    echo "❌ Secret YAML format is incorrect (missing quotes)"
fi
echo ""

echo "=== Environment check complete ==="
