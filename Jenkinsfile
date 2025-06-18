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
                                        export LARAVEL_DB_HOST=$DB_HOST
                                        export LARAVEL_DB_PORT=$DB_PORT
                                        export LARAVEL_DB_DATABASE=$DB_DATABASE
                                        export LARAVEL_DB_USERNAME=$DB_USERNAME
                                        export LARAVEL_DB_PASSWORD=$DB_PASSWORD
                                        export LARAVEL_APP_URL=$APP_URL
                                        envsubst < k8s/deployment.yaml.template > k8s/deployment.yaml
                                    '''

                                    // 除錯：檢查 deployment.yaml 中的變數替換
                                    sh '''
                                        echo "=== Checking deployment.yaml ==="
                                        cat k8s/deployment.yaml
                                    '''

                                    // 測試集群連接
                                    sh 'kubectl cluster-info'

                                    // 檢查 deployment.yaml 文件
                                    sh 'ls -la k8s/'

                                    // 檢查 Deployment 是否存在
                                    sh '''
                                        if kubectl get deployment paprika -n default; then
                                            echo "Deployment exists, updating..."
                                            kubectl set image deployment/paprika paprika=${DOCKER_IMAGE}:${DOCKER_TAG} -n default
                                            kubectl rollout restart deployment paprika
                                        else
                                            echo "Deployment does not exist, creating..."
                                            kubectl apply -f k8s/deployment.yaml
                                        fi
                                    '''

                                    // 檢查部署狀態
                                    sh 'kubectl get deployments -n default'
                                    sh 'kubectl rollout status deployment/paprika'

                                    // 除錯：檢查 Pod 的環境變數
                                    sh '''
                                        echo "=== Checking Pod Environment Variables ==="
                                        POD_NAME=$(kubectl get pods -l app=paprika -o jsonpath="{.items[0].metadata.name}")
                                        CONTAINER_NAME=$(kubectl get pod $POD_NAME -o jsonpath="{.spec.containers[0].name}")
                                        echo "Using container: $CONTAINER_NAME"
                                        kubectl exec $POD_NAME -c $CONTAINER_NAME -- env | grep -E "APP_|DB_"
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
