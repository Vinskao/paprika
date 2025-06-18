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

                            # 安裝 Composer
                            curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

                            # 安裝依賴
                            composer install --no-dev --optimize-autoloader

                            # 設置權限
                            chmod -R 777 storage bootstrap/cache
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
                                    // 除錯：檢查環境變數
                                    sh '''
                                        echo "=== Checking Environment Variables ==="
                                        echo "DB_HOST: ${DB_HOST}"
                                        echo "DB_PORT: ${DB_PORT}"
                                        echo "DB_DATABASE: ${DB_DATABASE}"
                                        echo "DB_USERNAME: ${DB_USERNAME}"
                                        echo "DB_PASSWORD: [MASKED]"
                                        echo "APP_URL: ${APP_URL}"
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
                                    def secretYaml = """
apiVersion: v1
kind: Secret
metadata:
  name: paprika-secrets
type: Opaque
stringData:
  LARAVEL_DATABASE_HOST: "${DB_HOST}"
  LARAVEL_DATABASE_PORT_NUMBER: "${DB_PORT}"
  LARAVEL_DATABASE_NAME: "${DB_DATABASE}"
  LARAVEL_DATABASE_USER: "${DB_USERNAME}"
  LARAVEL_DATABASE_PASSWORD: "${DB_PASSWORD}"
  LARAVEL_HOST: "${APP_URL}"
  LARAVEL_DATABASE_CONNECTION: "pgsql"
"""
                                    writeFile file: 'k8s/secret.yaml', text: secretYaml

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
  LARAVEL_LOG_CHANNEL: "stack"
  LARAVEL_LOG_LEVEL: "debug"
  LARAVEL_CACHE_DRIVER: "file"
  LARAVEL_FILESYSTEM_DISK: "local"
  LARAVEL_SESSION_DRIVER: "file"
  LARAVEL_SESSION_LIFETIME: "120"
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
        - containerPort: 8080
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
        - name: LARAVEL_HOST
          valueFrom:
            secretKeyRef:
              name: paprika-secrets
              key: LARAVEL_HOST
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
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: paprika-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: peoplesystem.tatdvsonorth.com
    http:
      paths:
      - path: /paprika
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
                                        kubectl wait --for=condition=Ready pod -l app=paprika --timeout=60s

                                        # 檢查 Pod 狀態
                                        echo "=== Checking Pod Status ==="
                                        kubectl get pods -l app=paprika

                                        # 檢查 Pod 日誌
                                        echo "=== Checking Pod Logs ==="
                                        POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}")
                                        kubectl logs $POD_NAME

                                        # 檢查環境變數是否正確設置
                                        echo "=== Checking Pod Environment Variables ==="
                                        kubectl exec $POD_NAME -c paprika -- env | grep LARAVEL_
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
