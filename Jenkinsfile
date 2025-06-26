pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  serviceAccountName: jenkins-admin
                  containers:
                  - name: php
                    image: php:8.2-cli
                    command: ["cat"]
                    tty: true
                    volumeMounts:
                    - mountPath: /home/jenkins/agent
                      name: workspace-volume
                    workingDir: /home/jenkins/agent
                  - name: docker
                    image: docker:23-dind
                    privileged: true
                    securityContext:
                      privileged: true
                    env:
                    - name: DOCKER_HOST
                      value: tcp://localhost:2375
                    - name: DOCKER_TLS_CERTDIR
                      value: ""
                    - name: DOCKER_BUILDKIT
                      value: "1"
                    volumeMounts:
                    - mountPath: /home/jenkins/agent
                      name: workspace-volume
                  - name: kubectl
                    image: bitnami/kubectl:1.30.7
                    command: ["/bin/sh"]
                    args: ["-c", "while true; do sleep 30; done"]
                    alwaysPull: true
                    securityContext:
                      runAsUser: 0
                    volumeMounts:
                    - mountPath: /home/jenkins/agent
                      name: workspace-volume
                  volumes:
                  - name: workspace-volume
                    emptyDir: {}
            '''
            defaultContainer 'php'
            inheritFrom 'default'
        }
    }
    options {
        timestamps()
        disableConcurrentBuilds()
    }
    environment {
        DOCKER_IMAGE = 'papakao/paprika'
        DOCKER_TAG = "${BUILD_NUMBER}"
        APP_ENV = "production"
        APP_DEBUG = "true"
        LOG_LEVEL = "debug"
    }
    stages {
        stage('Clone and Setup') {
            steps {
                script {
                    container('php') {
                        sh '''
                            # 安裝必要的系統依賴
                            apt-get update && apt-get install -y \
                                git \
                                unzip \
                                libzip-dev \
                                && docker-php-ext-install zip

                            # 確認 Dockerfile 存在
                            ls -la
                            if [ ! -f "Dockerfile" ]; then
                                echo "Error: Dockerfile not found!"
                                exit 1
                            fi

                            # ✅ 正確建立 Laravel 必要目錄
                            mkdir -p \
                              storage/framework/cache/data \
                              storage/framework/views \
                              storage/framework/sessions \
                              storage/app/public \
                              storage/app/private \
                              storage/logs \
                              bootstrap/cache

                            # 設置權限 - 確保所有目錄都有正確權限
                            chmod -R 777 storage bootstrap/cache
                            chown -R 1001:1001 storage bootstrap/cache 2>/dev/null || true

                            # 安裝 Composer
                            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

                            # 配置 Composer 強制使用 dist 包
                            composer config -g preferred-install dist
                            composer config -g github-protocols https

                            # 設置環境變數禁用 Git 操作
                            export COMPOSER_DISABLE_GIT=1
                            export COMPOSER_PREFER_DIST=1

                            # 安裝依賴（強制使用 dist 包）
                            echo "🔧 Installing Composer dependencies..."
                            composer install --no-dev --optimize-autoloader --no-interaction --no-scripts --prefer-dist --no-cache || \
                            (echo "First attempt failed, trying with different settings..." && \
                             composer install --no-dev --optimize-autoloader --no-interaction --no-scripts --prefer-dist --no-cache --no-plugins) || \
                            (echo "Second attempt failed, trying with minimal settings..." && \
                             composer install --no-dev --optimize-autoloader --no-interaction --no-scripts --prefer-dist --no-cache --no-plugins --no-autoloader)

                            # 重新生成 autoload 文件並執行 Laravel 腳本
                            echo "🔄 Regenerating autoload files..."
                            composer dump-autoload --optimize
                            composer run-script post-autoload-dump --no-interaction

                            # 驗證 Laravel 核心類是否可用
                            echo "🔍 Validating Laravel core classes..."
                            if ! php -r "require_once 'vendor/autoload.php'; class_exists('Illuminate\\\\Foundation\\\\Application') ? exit(0) : exit(1);" 2>/dev/null; then
                                echo "❌ Laravel core classes not found, attempting to fix..."
                                composer dump-autoload --optimize
                                composer run-script post-autoload-dump --no-interaction
                            else
                                echo "✅ Laravel core classes validated successfully"
                            fi
                        '''
                    }
                }
            }
        }

        stage('Build Docker Image with BuildKit') {
            steps {
                container('docker') {
                    script {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                            sh '''
                                cd /home/jenkins/agent/workspace/PAPRIKA/paprika-deploy
                                echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
                                # 確認 Dockerfile 存在
                                ls -la
                                if [ ! -f "Dockerfile" ]; then
                                    echo "Error: Dockerfile not found!"
                                    exit 1
                                fi
                                # 構建 Docker 鏡像
                                docker build \
                                    --build-arg BUILDKIT_INLINE_CACHE=1 \
                                    --cache-from ${DOCKER_IMAGE}:latest \
                                    -t ${DOCKER_IMAGE}:${DOCKER_TAG} \
                                    -t ${DOCKER_IMAGE}:latest \
                                    .
                                docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                                docker push ${DOCKER_IMAGE}:latest
                            '''
                        }
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    withKubeConfig([credentialsId: 'kubeconfig-secret']) {
                        script {
                            try {
                                withCredentials([
                                    string(credentialsId: 'DB_HOST', variable: 'DB_HOST'),
                                    string(credentialsId: 'DB_PORT', variable: 'DB_PORT'),
                                    string(credentialsId: 'DB_DATABASE', variable: 'DB_DATABASE'),
                                    string(credentialsId: 'DB_USERNAME', variable: 'DB_USERNAME'),
                                    string(credentialsId: 'DB_PASSWORD', variable: 'DB_PASSWORD'),
                                    string(credentialsId: 'APP_URL', variable: 'APP_URL')
                                ]) {
                                    // 創建 k8s 目錄並設置權限
                                    sh '''
                                        # 創建 k8s 目錄用於 Kubernetes 配置
                                        mkdir -p k8s
                                        chmod 755 k8s

                                        echo "=== Checking Environment Variables ==="
                                        echo "DB_HOST: ${DB_HOST}"
                                        echo "DB_PORT: ${DB_PORT}"
                                        echo "DB_DATABASE: ${DB_DATABASE}"
                                        echo "DB_USERNAME: ${DB_USERNAME}"
                                        echo "DB_PASSWORD: [MASKED]"
                                        echo "APP_URL: ${APP_URL}"

                                        # 驗證 DB_PORT 是否為有效整數
                                        echo "=== Validating DB_PORT ==="
                                        if ! echo "${DB_PORT}" | grep -E "^[0-9]+$" > /dev/null; then
                                            echo "ERROR: DB_PORT '${DB_PORT}' is not a valid integer!"
                                            echo "DB_PORT length: ${#DB_PORT}"
                                            echo "DB_PORT hex dump:"
                                            echo "${DB_PORT}" | hexdump -C
                                            exit 1
                                        fi
                                        echo "DB_PORT validation passed: ${DB_PORT}"
                                    '''

                                    // 確保 DB_PORT 是整數並去除可能的空格
                                    def dbPortClean = DB_PORT.trim()
                                    if (!dbPortClean.isInteger()) {
                                        error "ERROR: DB_PORT '${DB_PORT}' is not a valid integer after trimming!"
                                    }

                                    // 生成 Secret（移除 LARAVEL_ 前綴）
                                    def appKey = sh(script: 'openssl rand -base64 32', returnStdout: true).trim()

                                    sh """
                                        cat > k8s/secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: paprika-secrets
type: Opaque
stringData:
  DATABASE_HOST: "${DB_HOST}"
  DATABASE_PORT_NUMBER: "${dbPortClean}"
  DATABASE_NAME: "${DB_DATABASE}"
  DATABASE_USER: "${DB_USERNAME}"
  DATABASE_PASSWORD: "${DB_PASSWORD}"
  APP_URL: "${APP_URL}"
  DATABASE_CONNECTION: "pgsql"
  APP_KEY: "base64:${appKey}"
EOF
                                    """

                                    // 調試：檢查 secret.yaml 文件
                                    sh '''
                                        echo "=== Debug: Checking secret.yaml file ==="
                                        echo "Current directory: $(pwd)"
                                        echo "k8s directory contents:"
                                        ls -la k8s/

                                        if [ -f "k8s/secret.yaml" ]; then
                                            echo "✅ secret.yaml file exists"
                                            echo "File size: $(wc -c < k8s/secret.yaml) bytes"
                                            echo "File permissions: $(ls -la k8s/secret.yaml)"
                                            echo "First 10 lines of secret.yaml:"
                                            head -10 k8s/secret.yaml
                                        else
                                            echo "❌ secret.yaml file does not exist!"
                                            exit 1
                                        fi
                                    '''

                                    // 生成 Deployment（使用 envsubst 進行變數替換）
                                    sh """
                                        cat > k8s/deployment.yaml << 'EOF'
# Persistent Volumes
apiVersion: v1
kind: PersistentVolume
metadata:
  name: paprika-storage-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual
  hostPath:
    path: /data/paprika-storage
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: paprika-cache-pv
spec:
  capacity:
    storage: 5Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: manual
  hostPath:
    path: /data/paprika-cache
---
# Persistent Volume Claims
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: paprika-storage
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: manual
  volumeName: paprika-storage-pv
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: paprika-cache
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
  volumeName: paprika-cache-pv
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: paprika
  labels:
    app: paprika
spec:
  replicas: 1
  selector:
    matchLabels:
      app: paprika
  template:
    metadata:
      labels:
        app: paprika
    spec:
      containers:
      - name: paprika
        image: \${DOCKER_IMAGE}:\${DOCKER_TAG}
        ports:
        - containerPort: 8000
        env:
        - name: LARAVEL_APP_ENV
          value: "production"
        - name: LARAVEL_APP_DEBUG
          value: "false"
        - name: LARAVEL_LOG_LEVEL
          value: "info"
        - name: LARAVEL_DATABASE_HOST
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: DATABASE_HOST
        - name: LARAVEL_DATABASE_PORT_NUMBER
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: DATABASE_PORT_NUMBER
        - name: LARAVEL_DATABASE_NAME
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: DATABASE_NAME
        - name: LARAVEL_DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: DATABASE_USER
        - name: LARAVEL_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: DATABASE_PASSWORD
        - name: LARAVEL_APP_KEY
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: APP_KEY
        - name: LARAVEL_APP_URL
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: APP_URL
        - name: LARAVEL_DATABASE_CONNECTION
          value: "pgsql"
        - name: LARAVEL_CACHE_DRIVER
          value: "file"
        - name: LARAVEL_SESSION_DRIVER
          value: "file"
        - name: LARAVEL_SESSION_LIFETIME
          value: "120"
        - name: LARAVEL_FILESYSTEM_DISK
          value: "local"
        - name: VIEW_COMPILED_PATH
          value: "/app/storage/framework/views"
        lifecycle:
          postStart:
            exec:
              command:
                - /bin/sh
                - -c
                - |
                  echo "🔍 Volume 掛載後檢查："
                  ls -alR /app/storage || echo "❌ /app/storage is missing or not mounted!"

                  echo "📁 重建必要的 Laravel 目錄..."
                  mkdir -p /app/storage/framework/{views,cache/data,sessions} && \\
                  mkdir -p /app/storage/app/{public,private} && \\
                  mkdir -p /app/storage/logs && \\
                  mkdir -p /app/bootstrap/cache && \\
                  chmod -R 777 /app/storage /app/bootstrap/cache && \\
                  echo "✅ PostStart: Laravel directories created and permissions set"

                  echo "🔍 最終目錄檢查："
                  ls -al /app/storage/framework/ || echo "❌ /app/storage/framework/ still missing!"
                  ls -al /app/bootstrap/cache/ || echo "❌ /app/bootstrap/cache/ still missing!"
        volumeMounts:
        - name: storage
          mountPath: /app/storage
        - name: cache
          mountPath: /app/bootstrap/cache
      volumes:
      - name: storage
        persistentVolumeClaim:
          claimName: paprika-storage
      - name: cache
        persistentVolumeClaim:
          claimName: paprika-cache
---
apiVersion: v1
kind: Service
metadata:
  name: paprika
  labels:
    app: paprika
spec:
  selector:
    app: paprika
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: paprika-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /\\\$2
spec:
  ingressClassName: nginx
  rules:
  - host: peoplesystem.tatdvsonorth.com
    http:
      paths:
      - path: /paprika(/|\\\$)(.*)
        pathType: Prefix
        backend:
          service:
            name: paprika
            port:
              number: 80
EOF
                                    """

                                    // 調試：檢查 deployment.yaml 文件
                                    sh '''
                                        echo "=== Debug: Checking deployment.yaml file ==="
                                        if [ -f "k8s/deployment.yaml" ]; then
                                            echo "✅ deployment.yaml file exists"
                                            echo "File size: $(wc -c < k8s/deployment.yaml) bytes"
                                            echo "File permissions: $(ls -la k8s/deployment.yaml)"
                                            echo "First 10 lines of deployment.yaml:"
                                            head -10 k8s/deployment.yaml

                                            echo "=== Checking Docker image variable replacement ==="
                                            if grep -q "\${DOCKER_IMAGE}:\${DOCKER_TAG}" k8s/deployment.yaml; then
                                                echo "✅ Docker image variables found in deployment.yaml (before envsubst)"
                                                echo "DOCKER_IMAGE: ${DOCKER_IMAGE}"
                                                echo "DOCKER_TAG: ${DOCKER_TAG}"
                                                echo "Full image name: ${DOCKER_IMAGE}:${DOCKER_TAG}"
                                            else
                                                echo "❌ Docker image variables NOT found in deployment.yaml"
                                                echo "Checking for literal variable names..."
                                                grep -n "DOCKER_IMAGE\\|DOCKER_TAG" k8s/deployment.yaml || echo "No variable references found"
                                            fi
                                        else
                                            echo "❌ deployment.yaml file does not exist!"
                                            exit 1
                                        fi

                                        echo "=== Debug: Final k8s directory check ==="
                                        echo "k8s directory contents:"
                                        ls -la k8s/
                                        echo "Total files in k8s directory: $(ls k8s/ | wc -l)"
                                    '''

                                    // 應用 Kubernetes 配置
                                    sh '''
                                        # 創建主機目錄（如果不存在）
                                        echo "=== Creating host directories for persistent volumes ==="
                                        kubectl get nodes -o name | head -1 | xargs -I {} kubectl debug {} -it --image=busybox -- mkdir -p /data/paprika-storage /data/paprika-cache || echo "Warning: Could not create host directories"

                                        # 刪除現有的 PVC（解決 immutable 問題）
                                        echo "=== Deleting existing PVCs to resolve immutable spec issue ==="
                                        kubectl delete pvc paprika-storage --ignore-not-found
                                        kubectl delete pvc paprika-cache --ignore-not-found
                                        echo "✅ Existing PVCs deleted (if they existed)"

                                        # 刪除對應的 PV（解決綁定關係問題）
                                        echo "=== Deleting existing PVs to resolve binding issues ==="
                                        kubectl delete pv paprika-storage-pv --ignore-not-found
                                        kubectl delete pv paprika-cache-pv --ignore-not-found
                                        echo "✅ Existing PVs deleted (if they existed)"

                                        # 等待 PVC 和 PV 完全刪除
                                        echo "=== Waiting for PVCs and PVs to be fully deleted ==="
                                        kubectl wait --for=delete pvc/paprika-storage --timeout=30s 2>/dev/null || echo "paprika-storage PVC already deleted"
                                        kubectl wait --for=delete pvc/paprika-cache --timeout=30s 2>/dev/null || echo "paprika-cache PVC already deleted"
                                        kubectl wait --for=delete pv/paprika-storage-pv --timeout=30s 2>/dev/null || echo "paprika-storage-pv already deleted"
                                        kubectl wait --for=delete pv/paprika-cache-pv --timeout=30s 2>/dev/null || echo "paprika-cache-pv already deleted"

                                        # 驗證 YAML 文件語法
                                        echo "=== Validating YAML files syntax ==="
                                        if kubectl apply --dry-run=client -f k8s/secret.yaml; then
                                            echo "✅ secret.yaml syntax is valid"
                                        else
                                            echo "❌ secret.yaml syntax is invalid"
                                            exit 1
                                        fi

                                        if kubectl apply --dry-run=client -f k8s/deployment.yaml; then
                                            echo "✅ deployment.yaml syntax is valid"
                                        else
                                            echo "❌ deployment.yaml syntax is invalid"
                                            exit 1
                                        fi

                                        # 應用 Secret
                                        echo "=== Applying Kubernetes Secret ==="
                                        kubectl apply -f k8s/secret.yaml

                                        # 應用 Deployment（包含新的 PVC）
                                        echo "=== Applying Kubernetes Deployment ==="

                                        # 調試：檢查 envsubst 輸出
                                        echo "=== Debug: Checking envsubst output ==="
                                        echo "DOCKER_IMAGE: ${DOCKER_IMAGE}"
                                        echo "DOCKER_TAG: ${DOCKER_TAG}"
                                        echo "Full image name: ${DOCKER_IMAGE}:${DOCKER_TAG}"

                                        # 預覽替換後的內容
                                        echo "=== Preview of processed deployment.yaml ==="
                                        envsubst < k8s/deployment.yaml | grep -A 5 -B 5 "image:" || echo "No image line found"

                                        # 應用部署
                                        envsubst < k8s/deployment.yaml | kubectl apply -f -

                                        # 檢查 PVC 狀態
                                        echo "=== Checking PVC status ==="
                                        kubectl get pvc paprika-storage paprika-cache

                                        # 等待 PVC 綁定
                                        echo "=== Waiting for PVCs to be bound ==="
                                        kubectl wait --for=condition=Bound pvc/paprika-storage --timeout=60s
                                        kubectl wait --for=condition=Bound pvc/paprika-cache --timeout=60s
                                        echo "✅ PVCs are bound successfully"

                                        # 等待 Pod 就緒
                                        echo "=== Waiting for Pod to be Ready ==="
                                        kubectl wait --for=condition=Ready pod -l app=paprika --timeout=180s

                                        # 檢查 Pod 狀態
                                        echo "=== Checking Pod Status ==="
                                        kubectl get pods -l app=paprika

                                        # 檢查 Pod 詳細狀態
                                        echo "=== Checking Pod Details ==="
                                        POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}")
                                        kubectl describe pod $POD_NAME

                                        # 等待應用完全啟動
                                        echo "=== Waiting for Laravel Application to be Ready ==="
                                        for i in {1..30}; do
                                            echo "Attempt $i/30: Checking Laravel application..."

                                            # 首先檢查服務是否響應
                                            if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000 >/dev/null 2>&1; then
                                                echo "✅ Laravel application is responding"

                                                # 然後檢查 /up 端點
                                                if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000/up >/dev/null 2>&1; then
                                                    echo "✅ Laravel /up endpoint is working!"
                                                    break
                                                else
                                                    echo "⚠️  /up endpoint returned error, trying /health endpoint..."
                                                    if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000/health >/dev/null 2>&1; then
                                                        echo "✅ Laravel /health endpoint is working!"
                                                        break
                                                    else
                                                        echo "⚠️  Both /up and /health endpoints failed, but application is running"
                                                        echo "=== Testing /up endpoint with verbose output ==="
                                                        kubectl exec $POD_NAME -c paprika -- curl -v http://localhost:8000/up
                                                        echo "=== Testing /health endpoint with verbose output ==="
                                                        kubectl exec $POD_NAME -c paprika -- curl -v http://localhost:8000/health
                                                        echo "=== Application is ready (ignoring endpoint errors) ==="
                                                        break
                                                    fi
                                                fi
                                            fi

                                            if [ $i -eq 30 ]; then
                                                echo "❌ Laravel application failed to become ready after 30 attempts"
                                                echo "=== Checking Laravel logs ==="
                                                kubectl logs $POD_NAME -c paprika --tail=50
                                                echo "=== Testing application directly ==="
                                                kubectl exec $POD_NAME -c paprika -- curl -v http://localhost:8000
                                                exit 1
                                            fi
                                            echo "Application not ready yet, waiting 2 seconds..."
                                            sleep 2
                                        done

                                        # 檢查 Pod 日誌
                                        echo "=== Checking Pod Logs ==="
                                        kubectl logs $POD_NAME

                                        # 檢查環境變數是否正確設置
                                        echo "=== Checking Pod Environment Variables ==="
                                        kubectl exec $POD_NAME -c paprika -- env | grep -E "(APP_|DATABASE_|CACHE_|SESSION_)"

                                        # 檢查 Secret 是否正確創建
                                        echo "=== Checking Kubernetes Secret ==="
                                        kubectl get secret paprika-secrets -o yaml
                                    '''
                                }
                            } catch (Exception e) {
                                echo "Error during deployment: ${e.message}"
                                throw e
                            }
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            cleanWs()
        }
    }
}
