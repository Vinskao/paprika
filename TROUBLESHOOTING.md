# Laravel Database Port Number 故障排除指南

## 問題描述
錯誤訊息：`ERROR ==> An invalid port was specified in the environment variable LARAVEL_DATABASE_PORT_NUMBER: value is not an integer.`

## 可能的原因

### 1. Jenkins Credentials 問題
- `DB_PORT` credential 可能包含空格或非數字字符
- Credential 值可能為空或未正確設置

### 2. 變數插值問題
- Groovy GString 插值可能失敗
- 環境變數可能沒有正確傳遞

### 3. Kubernetes Secret 問題
- Secret 可能沒有正確創建
- 環境變數可能沒有正確映射到 Pod

## 解決方案

### 步驟 1: 檢查 Jenkins Credentials
1. 進入 Jenkins > Credentials > System > Global credentials
2. 找到 `DB_PORT` credential
3. 確保值只包含數字，沒有空格或其他字符
4. 建議值：`5432` (PostgreSQL 預設端口)

### 步驟 2: 驗證 Jenkins Pipeline
修改後的 Jenkinsfile 包含以下驗證：

```groovy
// 確保 DB_PORT 是整數並去除可能的空格
def dbPortClean = DB_PORT.trim()
if (!dbPortClean.isInteger()) {
    error "ERROR: DB_PORT '${DB_PORT}' is not a valid integer after trimming!"
}
```

### 步驟 3: 檢查生成的 Secret
Pipeline 會輸出生成的 Secret YAML 內容，檢查：
- `LARAVEL_DATABASE_PORT_NUMBER` 是否包含正確的數字
- 沒有 `${DB_PORT}` 這樣的字串殘留

### 步驟 4: 驗證 Pod 環境變數
Pipeline 會執行以下檢查：
```bash
kubectl exec $POD_NAME -c paprika -- env | grep LARAVEL_DATABASE_PORT_NUMBER
```

## 除錯步驟

### 1. 檢查 Jenkins Console Log
查看以下輸出：
- `=== Running Environment Debug Script ===`
- `=== Generated Secret YAML ===`
- `=== Verifying written secret.yaml ===`

### 2. 手動檢查 Kubernetes Secret
```bash
kubectl get secret paprika-secrets -o yaml
```

### 3. 檢查 Pod 環境變數
```bash
kubectl exec <pod-name> -c paprika -- env | grep LARAVEL_DATABASE_PORT_NUMBER
```

### 4. 檢查 Pod 日誌
```bash
kubectl logs <pod-name> -c paprika
```

## 預防措施

### 1. 使用強類型驗證
```groovy
def dbPortClean = DB_PORT.trim()
if (!dbPortClean.isInteger()) {
    error "ERROR: DB_PORT '${DB_PORT}' is not a valid integer!"
}
```

### 2. 加入詳細的除錯輸出
```groovy
echo "=== Generated Secret YAML ==="
echo secretYaml
```

### 3. 驗證 Secret 內容
```groovy
if (!secretYaml.contains("LARAVEL_DATABASE_PORT_NUMBER: ${dbPortClean}")) {
    error "ERROR: Secret YAML does not contain correct DB_PORT value!"
}
```

## 常見錯誤

### 錯誤 1: 變數插值失敗
**症狀**: Secret YAML 包含 `${DB_PORT}` 而不是實際數字
**解決**: 檢查 `withCredentials` 設置和變數名稱

### 錯誤 2: 空格問題
**症狀**: 端口值包含前導或尾隨空格
**解決**: 使用 `DB_PORT.trim()` 去除空格

### 錯誤 3: 非數字字符
**症狀**: 端口值包含字母或其他字符
**解決**: 檢查 Jenkins Credential 設置

### 錯誤 4: Kubernetes Secret stringData 類型錯誤
**症狀**: `cannot convert int64 to string` 錯誤
**原因**: Kubernetes Secret 的 `stringData` 欄位要求所有值都必須是字串類型
**解決**: 在 YAML 生成時為所有值加上雙引號

```groovy
// ❌ 錯誤：數字會被當作 int64
LARAVEL_DATABASE_PORT_NUMBER: ${dbPortClean}

// ✅ 正確：明確指定為字串
LARAVEL_DATABASE_PORT_NUMBER: "${dbPortClean}"
```

**完整的正確格式**：
```yaml
stringData:
  LARAVEL_DATABASE_HOST: "${DB_HOST}"
  LARAVEL_DATABASE_PORT_NUMBER: "${dbPortClean}"
  LARAVEL_DATABASE_NAME: "${DB_DATABASE}"
  LARAVEL_DATABASE_USER: "${DB_USERNAME}"
  LARAVEL_DATABASE_PASSWORD: "${DB_PASSWORD}"
  LARAVEL_HOST: "${APP_URL}"
  LARAVEL_DATABASE_CONNECTION: "pgsql"
  LARAVEL_APP_KEY: "base64:${sh(script: 'openssl rand -base64 32', returnStdout: true).trim()}"
```

### 錯誤 5: kubectl wait timeout 錯誤
**症狀**: `error: timed out waiting for the condition on pods/paprika-xxx`
**原因**: 
- Pod 重啟次數過多（如 RESTARTS: 83）
- 容器啟動時間超過預設的 60 秒 timeout
- Laravel 應用需要更多時間完成初始化

**解決**: 延長 timeout 時間並加入應用健康檢查

```groovy
// ❌ 錯誤：timeout 太短
kubectl wait --for=condition=Ready pod -l app=paprika --timeout=60s

// ✅ 正確：延長 timeout 並加入應用檢查
kubectl wait --for=condition=Ready pod -l app=paprika --timeout=180s

// 額外的應用健康檢查
for i in {1..30}; do
    if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000/up >/dev/null 2>&1; then
        echo "✅ Laravel application is ready!"
        break
    fi
    sleep 2
done
```

**檢查 Pod 狀態**：
```bash
# 檢查 Pod 重啟次數
kubectl get pods -l app=paprika

# 檢查 Pod 詳細狀態
kubectl describe pod <pod-name>

# 檢查容器日誌
kubectl logs <pod-name> -c paprika --tail=50
```

## 測試腳本
使用 `debug-env.sh` 腳本來診斷環境變數問題：
```bash
chmod +x debug-env.sh
./debug-env.sh
```

這個腳本會：
- 檢查所有環境變數
- 驗證 DB_PORT 是否為有效整數
- 測試變數插值
- 提供詳細的除錯信息 
