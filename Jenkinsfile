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

        stage('Debug Environment') {
            steps {
                container('kubectl') {
                    script {
                        echo "=== Listing all environment variables ==="
                        sh 'printenv | sort'
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    withCredentials([
                        string(credentialsId: 'DB_HOST', variable: 'DB_HOST'),
                        string(credentialsId: 'DB_PORT', variable: 'DB_PORT'),
                        string(credentialsId: 'DB_DATABASE', variable: 'DB_DATABASE'),
                        string(credentialsId: 'DB_USERNAME', variable: 'DB_USERNAME'),
                        string(credentialsId: 'DB_PASSWORD', variable: 'DB_PASSWORD')
                    ]) {
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USERNAME', passwordVariable: 'DOCKER_PASSWORD')]) {
                            script {
                                try {
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

                                        # Generate APP_KEY
                                        APP_KEY="base64:$(openssl rand -base64 32)"

                                        # Clean DB_PORT (remove spaces)
                                        DB_PORT_CLEAN=$(echo "${DB_PORT}" | tr -d ' ')

                                        # Create secret.yaml
                                        cat > k8s/secret.yaml << EOF
apiVersion: v1
kind: Secret
metadata:
  name: paprika-secret
type: Opaque
data:
  DATABASE_CONNECTION: cGdzcWw=
  DATABASE_HOST: $(echo -n "${DB_HOST}" | base64)
  DATABASE_PORT_NUMBER: $(echo -n "${DB_PORT_CLEAN}" | base64)
  DATABASE_NAME: $(echo -n "${DB_DATABASE}" | base64)
  DATABASE_USERNAME: $(echo -n "${DB_USERNAME}" | base64)
  DATABASE_PASSWORD: $(echo -n "${DB_PASSWORD}" | base64)
  APP_KEY: $(echo -n "${APP_KEY}" | base64)
EOF

                                        # Inspect manifest directory
                                        ls -la k8s/

                                        echo "Recreating deployment ..."
                                        echo "=== Effective sensitive env values ==="
                                        echo "DB_HOST=${DB_HOST}"
                                        echo "DB_PORT=${DB_PORT_CLEAN}"
                                        echo "DB_DATABASE=${DB_DATABASE}"

                                        kubectl delete deployment paprika -n default --ignore-not-found
                                        kubectl apply -f k8s/secret.yaml
                                        DOCKER_IMAGE=${DOCKER_IMAGE} DOCKER_TAG=${DOCKER_TAG} envsubst '${DOCKER_IMAGE} ${DOCKER_TAG}' < k8s/deployment.yaml | kubectl apply -f -
                                        kubectl set image deployment/paprika paprika=${DOCKER_IMAGE}:${DOCKER_TAG} -n default
                                        kubectl rollout status deployment/paprika -n default
                                    '''

                                    // 檢查部署狀態
                                    sh 'kubectl get deployments -n default'
                                    sh 'kubectl rollout status deployment/paprika -n default'
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
                            } // end script
                        } // end inner withCredentials
                    } // end outer withCredentials
                } // end container
            } // end steps
        } // end stage
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
