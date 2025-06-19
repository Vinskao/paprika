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

                            # 創建必要的 Laravel 目錄結構
                            mkdir -p storage/framework/{cache,views,sessions}
                            mkdir -p storage/app/{public,private}
                            mkdir -p storage/logs
                            mkdir -p bootstrap/cache

                            # 創建 k8s 目錄用於 Kubernetes 配置
                            mkdir -p k8s

                            # 安裝 Composer
                            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

                            # 安裝依賴
                            composer install --no-dev --optimize-autoloader

                            # 設置權限 - 確保所有目錄都有正確權限
                            chmod -R 777 storage bootstrap/cache
                            chown -R 1001:1001 storage bootstrap/cache 2>/dev/null || true
                        '''
                    }
                }
            }
        }

        stage('Debug Environment') {
            steps {
                container('kubectl') {
                    script {
                        echo "=== Listing all environment variables ==="
                        sh 'printenv | sort'

                        echo "=== Checking Jenkins environment variables ==="
                        sh '''
                            echo "BUILD_NUMBER: ${BUILD_NUMBER}"
                            echo "BUILD_ID: ${BUILD_ID}"
                            echo "BUILD_URL: ${BUILD_URL}"
                            echo "JOB_NAME: ${JOB_NAME}"
                            echo "JOB_BASE_NAME: ${JOB_BASE_NAME}"
                            echo "WORKSPACE: ${WORKSPACE}"
                            echo "JENKINS_HOME: ${JENKINS_HOME}"
                            echo "JENKINS_URL: ${JENKINS_URL}"
                            echo "EXECUTOR_NUMBER: ${EXECUTOR_NUMBER}"
                            echo "NODE_NAME: ${NODE_NAME}"
                            echo "NODE_LABELS: ${NODE_LABELS}"
                            echo "PATH: ${PATH}"
                            echo "SHELL: ${SHELL}"
                            echo "HOME: ${HOME}"
                            echo "USER: ${USER}"
                            echo "DOCKER_IMAGE: ${DOCKER_IMAGE}"
                            echo "DOCKER_TAG: ${DOCKER_TAG}"
                            echo "APP_ENV: ${APP_ENV}"
                            echo "APP_DEBUG: ${APP_DEBUG}"
                            echo "LOG_LEVEL: ${LOG_LEVEL}"
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
                                    // 執行除錯腳本
                                    sh '''
                                        echo "=== Running Environment Debug Script ==="
                                        chmod +x debug-env.sh
                                        ./debug-env.sh
                                    '''

                                    // 除錯：檢查環境變數
                                    sh '''
                                        echo "=== Checking Environment Variables ==="
                                        echo "DB_HOST: ${DB_HOST}"
                                        echo "DB_PORT: ${DB_PORT}"
                                        echo "DB_DATABASE: ${DB_DATABASE}"
                                        echo "DB_USERNAME: ${DB_USERNAME}"
                                        echo "DB_PASSWORD: [MASKED]"
                                        echo "APP_URL: ${APP_URL}"

                                        # 驗證 DB_PORT 是否為有效整數
                                        echo "=== Validating DB_PORT ==="
                                        if [[ ! "${DB_PORT}" =~ ^[0-9]+$ ]]; then
                                            echo "ERROR: DB_PORT '${DB_PORT}' is not a valid integer!"
                                            echo "DB_PORT length: ${#DB_PORT}"
                                            echo "DB_PORT hex dump:"
                                            echo "${DB_PORT}" | hexdump -C
                                            exit 1
                                        fi
                                        echo "DB_PORT validation passed: ${DB_PORT}"
                                    '''

                                    // 設置環境變數並替換模板
                                    sh '''
                                        # Export Jenkins Credentials 為符合 Kubernetes Secret 名稱的環境變數
                                        export LARAVEL_DB_HOST="${DB_HOST}"
                                        export LARAVEL_DB_PORT="${DB_PORT}"
                                        export LARAVEL_DB_DATABASE="${DB_DATABASE}"
                                        export LARAVEL_DB_USERNAME="${DB_USERNAME}"
                                        export LARAVEL_DB_PASSWORD="${DB_PASSWORD}"
                                        export LARAVEL_APP_URL="${APP_URL}"

                                        # 檢查環境變數是否正確設置
                                        echo "=== Checking Environment Variables ==="
                                        env | grep LARAVEL_
                                    '''

                                    // 使用 Pipeline 變數替換生成 Secret
                                    // 確保 DB_PORT 是整數並去除可能的空格
                                    def dbPortClean = DB_PORT.trim()
                                    if (!dbPortClean.isInteger()) {
                                        error "ERROR: DB_PORT '${DB_PORT}' is not a valid integer after trimming!"
                                    }

                                    def secretYaml = """
apiVersion: v1
kind: Secret
metadata:
  name: paprika-secrets
type: Opaque
stringData:
  LARAVEL_DATABASE_HOST: "${DB_HOST}"
  LARAVEL_DATABASE_PORT_NUMBER: "${dbPortClean}"
  LARAVEL_DATABASE_NAME: "${DB_DATABASE}"
  LARAVEL_DATABASE_USER: "${DB_USERNAME}"
  LARAVEL_DATABASE_PASSWORD: "${DB_PASSWORD}"
  LARAVEL_HOST: "${APP_URL}"
  LARAVEL_DATABASE_CONNECTION: "pgsql"
  LARAVEL_APP_KEY: "base64:${sh(script: 'openssl rand -base64 32', returnStdout: true).trim()}"
"""

                                    // 除錯：檢查生成的 Secret YAML
                                    echo "=== Generated Secret YAML ==="
                                    echo secretYaml

                                    // 驗證 Secret YAML 中的端口值
                                    if (!secretYaml.contains("LARAVEL_DATABASE_PORT_NUMBER: \"${dbPortClean}\"")) {
                                        error "ERROR: Secret YAML does not contain correct DB_PORT value in string format!"
                                    }

                                    writeFile file: 'k8s/secret.yaml', text: secretYaml

                                    // 驗證寫入的檔案
                                    sh '''
                                        echo "=== Verifying written secret.yaml ==="
                                        cat k8s/secret.yaml
                                        echo "=== Checking for DB_PORT in secret.yaml ==="
                                        grep "LARAVEL_DATABASE_PORT_NUMBER" k8s/secret.yaml
                                    '''

                                    // 使用 Pipeline 變數替換生成 Deployment
                                    def deploymentYaml = """
apiVersion: v1
kind: ConfigMap
metadata:
  name: paprika-config
data:
  LARAVEL_APP_NAME: "Paprika"
  LARAVEL_APP_ENV: "production"
  LARAVEL_APP_DEBUG: "true"
  LARAVEL_APP_URL: "\${APP_URL}"
  LARAVEL_LOG_CHANNEL: "stack"
  LARAVEL_LOG_LEVEL: "debug"
  LARAVEL_CACHE_DRIVER: "file"
  LARAVEL_FILESYSTEM_DISK: "local"
  LARAVEL_SESSION_DRIVER: "file"
  LARAVEL_SESSION_LIFETIME: "120"
  LARAVEL_DATABASE_CONNECTION: "pgsql"
  LARAVEL_BROADCAST_DRIVER: "log"
  LARAVEL_QUEUE_CONNECTION: "sync"
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
        image: papakao/paprika:latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: paprika-config
        env:
        - name: LARAVEL_DATABASE_HOST
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_DATABASE_HOST
        - name: LARAVEL_DATABASE_PORT_NUMBER
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_DATABASE_PORT_NUMBER
        - name: LARAVEL_DATABASE_NAME
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_DATABASE_NAME
        - name: LARAVEL_DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_DATABASE_USER
        - name: LARAVEL_DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_DATABASE_PASSWORD
        - name: LARAVEL_APP_KEY
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_APP_KEY
        volumeMounts:
        - name: storage
          mountPath: /app/storage
        - name: cache
          mountPath: /app/bootstrap/cache
      volumes:
      - name: storage
        emptyDir: {}
      - name: cache
        emptyDir: {}
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
    nginx.ingress.kubernetes.io/rewrite-target: /\$2
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
"""
                                    writeFile file: 'k8s/deployment.yaml', text: deploymentYaml

                                    // 應用 Kubernetes 配置
                                    sh '''
                                        # 應用 Secret
                                        echo "=== Applying Kubernetes Secret ==="
                                        kubectl apply -f k8s/secret.yaml

                                        # 應用 Deployment
                                        echo "=== Applying Kubernetes Deployment ==="
                                        kubectl apply -f k8s/deployment.yaml

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

                                        # 執行 Pod 健康檢查腳本
                                        echo "=== Running Pod Health Check Script ==="
                                        chmod +x check-pod-health.sh
                                        ./check-pod-health.sh

                                        # 檢查 Pod 重啟次數
                                        echo "=== Checking Pod Restart Count ==="
                                        kubectl get pods -l app=paprika -o jsonpath="{.items[0].status.containerStatuses[0].restartCount}"

                                        # 等待應用完全啟動
                                        echo "=== Waiting for Laravel Application to be Ready ==="
                                        for i in {1..30}; do
                                            echo "Attempt $i/30: Checking Laravel application..."
                                            if kubectl exec $POD_NAME -c paprika -- curl -f http://localhost:8000/up >/dev/null 2>&1; then
                                                echo "✅ Laravel application is ready!"
                                                break
                                            fi
                                            if [ $i -eq 30 ]; then
                                                echo "❌ Laravel application failed to become ready after 30 attempts"
                                                echo "=== Checking Laravel logs ==="
                                                kubectl logs $POD_NAME -c paprika --tail=50
                                                exit 1
                                            fi
                                            echo "Application not ready yet, waiting 2 seconds..."
                                            sleep 2
                                        done

                                        # 設置權限和執行 Laravel 維護命令
                                        echo "=== Setting Permissions and Running Laravel Commands ==="
                                        kubectl exec $POD_NAME -c paprika -- /bin/sh -c '
                                            # 確保目錄存在
                                            mkdir -p /app/storage/framework/views
                                            mkdir -p /app/storage/framework/cache
                                            mkdir -p /app/storage/framework/sessions
                                            mkdir -p /app/storage/app/public
                                            mkdir -p /app/storage/app/private
                                            mkdir -p /app/storage/logs
                                            mkdir -p /app/bootstrap/cache

                                            # 設置權限
                                            chmod -R 777 /app/storage
                                            chmod -R 777 /app/bootstrap/cache

                                            # 清除 Laravel 快取
                                            php artisan cache:clear
                                            php artisan config:clear
                                            php artisan view:clear
                                            php artisan route:clear

                                            echo "✅ Permissions and cache clearing completed"
                                        '

                                        # 動態產生 .env 檔案
                                        echo "=== Generating .env file dynamically ==="
                                        POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}")
                                        kubectl exec $POD_NAME -c paprika -- /bin/sh -c '
                                            cat <<EOF > /app/.env
                                            APP_NAME=Paprika
                                            APP_ENV=${LARAVEL_APP_ENV}
                                            APP_KEY=${LARAVEL_APP_KEY}
                                            APP_DEBUG=true
                                            APP_URL=${LARAVEL_APP_URL}

                                            LOG_CHANNEL=stack
                                            LOG_LEVEL=debug

                                            DB_CONNECTION=pgsql
                                            DB_HOST=${LARAVEL_DATABASE_HOST}
                                            DB_PORT=${LARAVEL_DATABASE_PORT_NUMBER}
                                            DB_DATABASE=${LARAVEL_DATABASE_NAME}
                                            DB_USERNAME=${LARAVEL_DATABASE_USER}
                                            DB_PASSWORD=${LARAVEL_DATABASE_PASSWORD}

                                            CACHE_DRIVER=file
                                            QUEUE_CONNECTION=sync
                                            SESSION_DRIVER=file
                                            SESSION_LIFETIME=120

                                            BROADCAST_DRIVER=log
                                            FILESYSTEM_DISK=local
                                            EOF

                                            echo ".env 建立完成"
                                            echo "檢查 .env 檔案內容："
                                            cat /app/.env
                                        '

                                        # 檢查 Pod 日誌
                                        echo "=== Checking Pod Logs ==="
                                        kubectl logs $POD_NAME

                                        # 檢查環境變數是否正確設置
                                        echo "=== Checking Pod Environment Variables ==="
                                        kubectl exec $POD_NAME -c paprika -- env | grep LARAVEL_

                                        # 詳細檢查 LARAVEL_DATABASE_PORT_NUMBER
                                        echo "=== Detailed DB_PORT Check ==="
                                        kubectl exec $POD_NAME -c paprika -- sh -c '
                                            echo "LARAVEL_DATABASE_PORT_NUMBER value: ${LARAVEL_DATABASE_PORT_NUMBER}"
                                            echo "LARAVEL_DATABASE_PORT_NUMBER length: ${#LARAVEL_DATABASE_PORT_NUMBER}"
                                            echo "LARAVEL_DATABASE_PORT_NUMBER hex dump:"
                                            echo "${LARAVEL_DATABASE_PORT_NUMBER}" | hexdump -C

                                            # 驗證是否為整數
                                            if [[ ! "${LARAVEL_DATABASE_PORT_NUMBER}" =~ ^[0-9]+$ ]]; then
                                                echo "ERROR: LARAVEL_DATABASE_PORT_NUMBER is not a valid integer!"
                                                exit 1
                                            fi
                                            echo "LARAVEL_DATABASE_PORT_NUMBER validation passed: ${LARAVEL_DATABASE_PORT_NUMBER}"
                                        '

                                        # 檢查 Secret 是否正確創建
                                        echo "=== Checking Kubernetes Secret ==="
                                        kubectl get secret paprika-secrets -o yaml

                                        # 檢查 Pod 的詳細狀態
                                        echo "=== Checking Pod Details ==="
                                        kubectl describe pod $POD_NAME
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
