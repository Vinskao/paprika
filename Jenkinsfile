pipeline {
    agent {
        kubernetes {
            yaml '''
                apiVersion: v1
                kind: Pod
                spec:
                  serviceAccountName: jenkins-admin
                  imagePullSecrets:
                  - name: dockerhub-credentials
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
                    imagePullPolicy: Always
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
                                cd "${WORKSPACE}"
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
                    script {
                        try {
                            withCredentials([
                                string(credentialsId: 'DB_HOST', variable: 'DB_HOST'),
                                string(credentialsId: 'DB_PORT', variable: 'DB_PORT'),
                                string(credentialsId: 'DB_DATABASE', variable: 'DB_DATABASE'),
                                string(credentialsId: 'DB_USERNAME', variable: 'DB_USERNAME'),
                                string(credentialsId: 'DB_PASSWORD', variable: 'DB_PASSWORD')
                            ]) {
                                withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                                    sh '''
                                        set -e

                                        # Ensure envsubst is available (try Debian then Alpine)
                                        if ! command -v envsubst >/dev/null 2>&1; then
                                          (apt-get update && apt-get install -y --no-install-recommends gettext-base ca-certificates) >/dev/null 2>&1 || true
                                          command -v envsubst >/dev/null 2>&1 || (apk add --no-cache gettext ca-certificates >/dev/null 2>&1 || true)
                                        fi

                                        # In-cluster auth via ServiceAccount (serviceAccountName: jenkins-admin)
                                        kubectl cluster-info

                                        # Ensure Docker Hub imagePullSecret exists in default namespace
                                        kubectl create secret docker-registry dockerhub-credentials \
                                          --docker-server=https://index.docker.io/v1/ \
                                          --docker-username="${DOCKER_USERNAME}" \
                                          --docker-password="${DOCKER_PASSWORD}" \
                                          --docker-email="none" \
                                          -n default \
                                          --dry-run=client -o yaml | kubectl apply -f -

                                        # 創建 k8s 目錄並設置權限
                                        mkdir -p k8s
                                        chmod 755 k8s

                                        echo "=== Checking Environment Variables ==="
                                        echo "DB_HOST: ${DB_HOST}"
                                        echo "DB_PORT: ${DB_PORT}"
                                        echo "DB_DATABASE: ${DB_DATABASE}"
                                        echo "DB_USERNAME: ${DB_USERNAME}"
                                        echo "DB_PASSWORD: [MASKED]"
                                        echo "APP_URL: http://peoplesystem.tatdvsonorth.com/paprika"

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

                                        # 確保 DB_PORT 是整數並去除可能的空格
                                        DB_PORT_CLEAN="${DB_PORT// /}"
                                        if ! [[ "$DB_PORT_CLEAN" =~ ^[0-9]+$ ]]; then
                                            echo "ERROR: DB_PORT '${DB_PORT}' is not a valid integer after trimming!"
                                            exit 1
                                        fi

                                        # 生成 Secret（移除 LARAVEL_ 前綴）
                                        APP_KEY=$(openssl rand -base64 32)

                                        cat > k8s/secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: paprika-secrets
type: Opaque
stringData:
  DATABASE_HOST: "${DB_HOST}"
  DATABASE_PORT_NUMBER: "${DB_PORT_CLEAN}"
  DATABASE_NAME: "${DB_DATABASE}"
  DATABASE_USER: "${DB_USERNAME}"
  DATABASE_PASSWORD: "${DB_PASSWORD}"
  # APP_URL removed from Secret; set directly in Deployment env
  DATABASE_CONNECTION: "pgsql"
  APP_KEY: "base64:${APP_KEY}"
EOF

                                        # 調試：檢查 secret.yaml 文件
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

                                        # 生成 Deployment（使用 envsubst 進行變數替換）
                                        cat > k8s/deployment.yaml << EOF
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
      imagePullSecrets:
      - name: dockerhub-credentials
      containers:
      - name: paprika
        image: ${DOCKER_IMAGE}:${DOCKER_TAG}
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
                 - name: APP_URL
           value: "http://peoplesystem.tatdvsonorth.com/paprika"
        - name: LARAVEL_DATABASE_CONNECTION
          value: "pgsql"
        - name: LARAVEL_CACHE_DRIVER
          value: "array"
        - name: LARAVEL_SESSION_DRIVER
          value: "array"
        - name: LARAVEL_SESSION_LIFETIME
          value: "120"
        - name: LARAVEL_FILESYSTEM_DISK
          value: "local"
        - name: VIEW_COMPILED_PATH
          value: "/tmp/views"
        lifecycle:
          postStart:
            exec:
              command:
                - /bin/sh
                - -c
                - |
                  echo "🔍 檢查應用目錄結構..."
                  ls -la /app/

                  echo "📁 創建臨時目錄..."
                  mkdir -p /tmp/views /tmp/cache /tmp/sessions /tmp/logs
                  chmod -R 777 /tmp/views /tmp/cache /tmp/sessions /tmp/logs
                  echo "✅ PostStart: 臨時目錄創建完成"

                  echo "🔍 最終目錄檢查："
                  ls -al /tmp/
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
    nginx.ingress.kubernetes.io/rewrite-target: /paprika/\$2
spec:
  ingressClassName: nginx
  rules:
  - host: peoplesystem.tatdvsonorth.com
    http:
      paths:
      - path: /paprika(/|\$)(.*)
        pathType: Prefix
        backend:
          service:
            name: paprika
            port:
              number: 80
EOF

                                        # 調試：檢查 deployment.yaml 文件
                                        echo "=== Debug: Checking deployment.yaml file ==="
                                        if [ -f "k8s/deployment.yaml" ]; then
                                            echo "✅ deployment.yaml file exists"
                                            echo "File size: $(wc -c < k8s/deployment.yaml) bytes"
                                            echo "File permissions: $(ls -la k8s/deployment.yaml)"
                                            echo "First 10 lines of deployment.yaml:"
                                            head -10 k8s/deployment.yaml

                                            echo "=== Checking Docker image variable replacement ==="
                                            if grep -q "${DOCKER_IMAGE}:${DOCKER_TAG}" k8s/deployment.yaml; then
                                                echo "✅ Docker image variables found in deployment.yaml"
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

                                        # 預覽替換後的內容
                                        echo "=== Preview of processed deployment.yaml ==="
                                        grep -A 5 -B 5 "image:" k8s/deployment.yaml || echo "No image line found"

                                        echo "Recreating deployment ..."
                                        echo "=== Effective sensitive env values ==="
                                        echo "DB_HOST: ${DB_HOST}"
                                        echo "DB_PORT: ${DB_PORT_CLEAN}"
                                        echo "DB_DATABASE: ${DB_DATABASE}"

                                        kubectl delete deployment paprika -n default --ignore-not-found
                                        kubectl apply -f k8s/secret.yaml
                                        kubectl apply -f k8s/deployment.yaml
                                        kubectl set image deployment/paprika paprika=${DOCKER_IMAGE}:${DOCKER_TAG} -n default
                                        kubectl rollout status deployment/paprika -n default
                                    '''

                                    // 檢查部署狀態
                                    sh 'kubectl get deployments -n default'
                                    sh 'kubectl rollout status deployment/paprika -n default'
                                } // end inner withCredentials
                            } // end outer withCredentials
                        } catch (Exception e) {
                            echo "Error during deployment: ${e.message}"
                            // Debug non-ready pods and recent events
                            sh '''
                                set +e
                                echo "=== Debug: pods for paprika ==="
                                kubectl get pods -n default -l app=paprika -o wide || true

                                echo "=== Debug: describe non-ready pods ==="
                                for p in $(kubectl get pods -n default -l app=paprika -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready")].status!="True")].metadata.name}'); do
                                  echo "--- $p"
                                  kubectl describe pod -n default "$p" || true
                                  echo "=== Last 200 logs for $p ==="
                                  kubectl logs -n default "$p" --tail=200 || true
                                done

                                echo "=== Recent events (default ns) ==="
                                kubectl get events -n default --sort-by=.lastTimestamp | tail -n 100 || true
                            '''
                            throw e
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            script {
                if (env.WORKSPACE) {
                    cleanWs()
                }
            }
        }
    }
}
