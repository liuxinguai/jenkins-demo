image_tag = "default"  //定一个全局变量，存储Docker镜像的tag（版本）
pipeline {
    agent any
    environment {
        GIT_REPO = "${env.gitlabSourceRepoName}"  //从Jenkins Gitlab插件中获取Git项目的名称
        GIT_BRANCH = "${env.gitlabTargetBranch}"  //项目的分支
        GIT_TAG = sh(returnStdout: true,script: 'git describe --tags --always').trim()  //commit id或tag名称
        DOCKER_REGISTER_CREDS = credentials('aliyun-docker-repo-creds') //docker registry凭证
        KUBE_CONFIG_LOCAL = credentials('local-k8s-kube-config')  //开发测试环境的kube凭证
        KUBE_CONFIG_PROD = "" //credentials('prod-k8s-kube-config') //生产环境的kube凭证

        DOCKER_REGISTRY = "registry.cn-shanghai.aliyuncs.com" //Docker仓库地址
        DOCKER_NAMESPACE = "jenkinstest"  //命名空间
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${GIT_REPO}" //Docker镜像地址

        INGRESS_HOST_DEV = "dev.your-site.com"    //开发环境的域名
        INGRESS_HOST_TEST = "test.your-site.com"  //测试环境的域名
        INGRESS_HOST_PROD = "prod.your-site.com"  //生产环境的域名
    }
    parameters {
        string(name: 'ingress_path', defaultValue: '/your-path', description: '服务上下文路径')
        string(name: 'replica_count', defaultValue: '1', description: '容器副本数量')
    }

    stages {
        stage('Code Analyze') {
            agent any
            steps {
               echo "1. 代码静态检查"
            }
        }
        stage('Maven Build') {
            agent {
                docker {
                    image 'maven:3-jdk-8-alpine'
                    args '-v $HOME/.m2:/root/.m2'
                }
            }
            steps {
                echo "2. 代码编译打包"
                sh 'mvn clean package -Dfile.encoding=UTF-8 -DskipTests=true'
            }
        }
        stage('Docker Build') {
            agent any
            steps {
                echo "3. 构建Docker镜像"
                echo "镜像地址： ${DOCKER_IMAGE}"
                //登录Docker仓库
                sh "sudo docker login -u ${DOCKER_REGISTER_CREDS_USR} -p ${DOCKER_REGISTER_CREDS_PSW} ${DOCKER_REGISTRY}"
                script {
                    def profile = "dev"
                    if (env.gitlabTargetBranch == "develop") {
                        image_tag = "dev." + env.GIT_TAG
                    } else if (env.gitlabTargetBranch == "pre-release") {
                        image_tag = "test." + env.GIT_TAG
                        profile = "test"
                    } else if (env.gitlabTargetBranch == "master"){
                        // master分支则直接使用Tag
                        image_tag = env.GIT_TAG
                        profile = "prod"
                    }
                    //通过--build-arg将profile进行设置，以区分不同环境进行镜像构建
                    sh "docker build  --build-arg profile=${profile} -t ${DOCKER_IMAGE}:${image_tag} ."
                    sh "sudo docker push ${DOCKER_IMAGE}:${image_tag}"
                    sh "docker rmi ${DOCKER_IMAGE}:${image_tag}"
                }
            }
        }
        stage('Helm Deploy') {
            agent {
                docker {
                    image 'lwolf/helm-kubectl-docker'
                    args '-u root:root'
                }
            }
            steps {
                echo "4. 部署到K8s"
                sh "mkdir -p /root/.kube"
                script {
                    def kube_config = env.KUBE_CONFIG_LOCAL
                    def ingress_host = env.INGRESS_HOST_DEV
                    if (env.gitlabTargetBranch == "pre-release") {
                        ingress_host = env.INGRESS_HOST_TEST
                    } else if (env.gitlabTargetBranch == "master"){
                        ingress_host = env.INGRESS_HOST_PROD
                        kube_config = env.KUBE_CONFIG_PROD
                    }
                    sh "echo ${kube_config} | base64 -d > /root/.kube/config"
                    //根据不同环境将服务部署到不同的namespace下，这里使用分支名称
                    sh "helm upgrade -i --namespace=${env.gitlabTargetBranch} --set replicaCount=${params.replica_count} --set image.repository=${DOCKER_IMAGE} --set image.tag=${image_tag} --set nameOverride=${GIT_REPO} ${GIT_REPO} ./jenkins-demo/"
                }
            }
        }
    }
}
