pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
        timestamps()
    }

    parameters {
        booleanParam(name: 'APPLY_TERRAFORM', defaultValue: false, description: 'Apply Terraform before building and deploying.')
        string(name: 'IMAGE_TAG_OVERRIDE', defaultValue: '', description: 'Optional image tag.')
    }

    environment {
        AWS_REGION     = 'ap-south-1'
        TF_ROOT        = 'my-flask-project/terraform'
        APP_ROOT       = 'my-flask-project/app'
        PROJECT_NAME   = 'flask-ecs'
        ENVIRONMENT    = 'dev'
        CONTAINER_NAME = 'flask-app'
        AWS_DEFAULT_REGION = "${AWS_REGION}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_SHA = sh(script: 'git rev-parse --short=8 HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = params.IMAGE_TAG_OVERRIDE?.trim() ? params.IMAGE_TAG_OVERRIDE.trim() : "${env.BUILD_NUMBER}-${env.GIT_SHA}"
                    env.ECR_REPOSITORY = "${env.PROJECT_NAME}-${env.ENVIRONMENT}"
                    env.ECS_CLUSTER = "${env.PROJECT_NAME}-${env.ENVIRONMENT}-cluster"
                    env.ECS_SERVICE = "${env.PROJECT_NAME}-${env.ENVIRONMENT}-service"
                    env.TASK_FAMILY = "${env.PROJECT_NAME}-${env.ENVIRONMENT}-task"
                }
            }
        }

        stage('Verify Tooling') {
            steps {
                sh 'aws --version'
                sh 'docker --version'
                sh 'terraform version'
                sh 'jq --version'
                sh 'curl --version | head -n 1'
            }
        }

        stage('Terraform Validate') {
            steps {
                dir(env.TF_ROOT) {
                    sh 'terraform init -backend=false'
                    sh 'terraform fmt -check -recursive'
                    sh 'terraform validate'
                }
            }
        }

        // ❌ DISABLED TERRAFORM APPLY
        // stage('Terraform Apply') {
        //     when {
        //         expression { return params.APPLY_TERRAFORM }
        //     }
        //     steps {
        //         withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
        //             dir(env.TF_ROOT) {
        //                 sh 'terraform init'
        //                 sh 'bash ../../scripts/import-existing-terraform-resources.sh .'
        //                 sh "terraform apply -auto-approve -var=image_tag=latest"
        //             }
        //         }
        //     }
        // }

        // ✅ NEW CLOUD FORMATION STAGE
        stage('CloudFormation Deploy') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
                    dir('cloudformation') {
                        sh '''
                        echo "=== Deploying ECR using CloudFormation ==="

                        aws cloudformation deploy \
                          --template-file ecr.yaml \
                          --stack-name flask-ecr-stack \
                          --region ${AWS_REGION}

                        echo "=== CloudFormation Deploy Complete ==="
                        '''
                    }
                }
            }
        }

        stage('Resolve AWS Targets') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
                    script {
                        env.AWS_ACCOUNT_ID = sh(
                            script: 'aws sts get-caller-identity --query Account --output text',
                            returnStdout: true
                        ).trim()
                        env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                        env.ECR_IMAGE = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                        env.ECR_IMAGE_LATEST = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:latest"
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                dir(env.APP_ROOT) {
                    sh "docker build -t ${env.ECR_REPOSITORY}:${env.IMAGE_TAG} ."
                }
            }
        }

        stage('Push To ECR') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_IMAGE}
                        docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_IMAGE_LATEST}
                        docker push ${ECR_IMAGE}
                        docker push ${ECR_IMAGE_LATEST}
                    """
                }
            }
        }

        stage('Deploy To ECS') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
                    sh '''
                        aws ecs describe-task-definition \
                          --region "$AWS_REGION" \
                          --task-definition "$TASK_FAMILY" \
                          --query taskDefinition \
                          --output json > task-definition.json

                        jq --arg IMAGE "$ECR_IMAGE" --arg CONTAINER "$CONTAINER_NAME" '
                          .containerDefinitions = (
                            .containerDefinitions | map(
                              if .name == $CONTAINER then .image = $IMAGE else . end
                            )
                          )
                          | del(
                              .taskDefinitionArn,
                              .revision,
                              .status,
                              .requiresAttributes,
                              .compatibilities,
                              .registeredAt,
                              .registeredBy,
                              .deregisteredAt
                            )
                        ' task-definition.json > task-definition-updated.json

                        NEW_TASK_ARN=$(aws ecs register-task-definition \
                          --region "$AWS_REGION" \
                          --cli-input-json file://task-definition-updated.json \
                          --query taskDefinition.taskDefinitionArn \
                          --output text)

                        aws ecs update-service \
                          --region "$AWS_REGION" \
                          --cluster "$ECS_CLUSTER" \
                          --service "$ECS_SERVICE" \
                          --task-definition "$NEW_TASK_ARN"

                        aws ecs wait services-stable \
                          --region "$AWS_REGION" \
                          --cluster "$ECS_CLUSTER" \
                          --services "$ECS_SERVICE"
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withAWS(credentials: 'aws-credentials', region: env.AWS_REGION) {
                    script {
                        def albDns = sh(
                            script: """
                                aws elbv2 describe-load-balancers \
                                  --region ${env.AWS_REGION} \
                                  --names ${env.PROJECT_NAME}-${env.ENVIRONMENT}-alb \
                                  --query 'LoadBalancers[0].DNSName' \
                                  --output text
                            """,
                            returnStdout: true
                        ).trim()
                        sh "curl -fsS http://${albDns}/health"
                    }
                }
            }
        }
    }

    post {
        always {
            sh 'rm -f task-definition.json task-definition-updated.json || true'
        }
    }
}