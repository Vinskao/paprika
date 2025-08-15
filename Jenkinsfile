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

        // Deployment to Kubernetes stage removed per request
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
