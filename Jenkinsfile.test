@Library('slack') _

import io.jenkins.blueocean.rest.impl.pipeline.PipelineNodeGraphVisitor
import io.jenkins.blueocean.rest.impl.pipeline.FlowNodeWrapper
import org.jenkinsci.plugins.workflow.support.steps.build.RunWrapper
import org.jenkinsci.plugins.workflow.actions.ErrorAction

// Get information about all stages, including the failure cases
@NonCPS
List<Map> getStageResults( RunWrapper build ) {
    def visitor = new PipelineNodeGraphVisitor( build.rawBuild )
    def stages = visitor.pipelineNodes.findAll{ it.type == FlowNodeWrapper.NodeType.STAGE }

    return stages.collect{ stage ->
        def errorActions = stage.getPipelineActions( ErrorAction )
        def errors = errorActions?.collect{ it.error }.unique()

        return [ 
            id: stage.id, 
            failedStageName: stage.displayName, 
            result: "${stage.status.result}",
            errors: errors
        ]
    }
}

// Get information of all failed stages
@NonCPS
List<Map> getFailedStages( RunWrapper build ) {
    return getStageResults( build ).findAll{ it.result == 'FAILURE' }
}

pipeline {
    agent any

    environment {
        IMAGE_NAME     = "chongchang/numeric-app"
        IMAGE_TAG      = "${GIT_COMMIT}"
        SONAR_KEY      = "numeric-application"
        SONAR_NAME     = "numeric-application"
        K8S_MANIFEST   = "k8s_deployment_service.yaml"
        TRIVY_REPORT   = "trivy-k8s-report.json"
        deploymentName = "devsecops"

        serviceName    = "devsecops-svc"
        applicationURL = "http://192.168.49.2"
        applicationURI = "/increment/99"
    }

    stages {

        // =========================================================================
        // SHELL EXIT CODE TEST STAGE
        // =========================================================================

        stage('Shell Test Stage') {
            steps {
                // Switch between 'exit 0' (Success) and 'exit 1' (Failure)
                sh 'exit 0'
            }
        }

        /*
        stage('Build Artifact - Maven') {
            steps {
                sh 'mvn clean package -DskipTests=true'
                archiveArtifacts artifacts: 'target/*.jar', allowEmptyArchive: false
            }
        }

        stage('Unit Tests - JUnit and JaCoCo') {
            steps {
                sh 'mvn test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    jacoco execPattern: 'target/jacoco.exec',
                           classPattern: 'target/classes',
                           sourcePattern: 'src/main/java'
                }
            }
        }

        stage('SAST - SonarQube') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh """
                        mvn verify org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                        -Dsonar.projectKey=${SONAR_KEY} \
                        -Dsonar.projectName='${SONAR_NAME}'
                    """
                }
                timeout(time: 2, unit: 'MINUTES') {
                    script {
                        waitForQualityGate abortPipeline: true
                    }
                }
            }
        }

        stage('Docker Build') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
            }
        }

        stage('Vulnerability Scan - Docker') {
            steps {
                parallel(
                    'Dependency Scan': {
                        withCredentials([string(credentialsId: 'nvd-api-key-credential-id', variable: 'NVD_API_KEY')]) {
                            sh 'mvn dependency-check:check -DnvdApiKey="${NVD_API_KEY}"'
                        }
                    },
                    'Trivy Scan': {
                        sh "bash trivy-docker-image-scan.sh ${IMAGE_NAME}:${IMAGE_TAG}"
                    },
                    'OPA Conftest Scan': {
                        sh '''
                            docker run --rm -v "${WORKSPACE}":/project \
                              openpolicyagent/conftest test \
                              --policy opa-docker-security.rego Dockerfile
                        '''
                    }
                )
            }
            post {
                always {
                    dependencyCheckPublisher pattern: 'target/dependency-check-report.xml'
                }
            }
        }

        stage('Kubernetes Security Scans') {
            steps {
                parallel(
                    'OPA Conftest Scan': {
                        sh '''
                            docker run --rm -v "${WORKSPACE}":/project \
                              openpolicyagent/conftest test \
                              --policy opa-k8s-security.rego k8s_deployment_service.yaml
                        '''
                    },
                    'Kubesec Scan': {
                        sh 'bash kubesec-scan.sh'
                    },
                    'Trivy Image Scan': {
                        sh 'bash trivy-k8s-scan.sh ${IMAGE_NAME}:${IMAGE_TAG}'
                    }
                )
            }
            post {
                always {
                    archiveArtifacts artifacts: "${TRIVY_REPORT}", allowEmptyArchive: true
                }
            }
        }

        stage('Docker Push') {
            steps {
                withDockerRegistry(credentialsId: 'docker-hub', url: '') {
                    sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Kubernetes Deployment - DEV') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh "sed 's#replace#${IMAGE_NAME}:${IMAGE_TAG}#g' ${K8S_MANIFEST} | kubectl apply -f -"
                    sh 'bash k8s-deployment-rollout-status.sh'
                }
            }
        }

        stage('Integration Tests') {
            steps {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    sh 'bash integration-test.sh'
                }
            }
        }

        stage('OWASP ZAP Scan') {
            steps {
                sh 'bash zap.sh'
            }
            post {
                always {
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: '.',
                        reportFiles: 'zap_report.html',
                        reportName: 'OWASP ZAP Security Report',
                        reportTitles: 'OWASP ZAP Report'
                    ])
                }
            }
        }
        */
    }

    post {
        success {
            script {
                echo "Build succeeded. Sending Slack notification..."
                sendNotification('SUCCESS')
            }
        }
        unstable {
            script {
                echo "Build unstable. Sending Slack notification..."
                sendNotification('UNSTABLE')
            }
        }
        failure {
            script {
                echo "Build failed. Fetching failed stages..."
                try {
                    def failedStagesList = getFailedStages(currentBuild)
                    def failedNames = failedStagesList.collect { it.failedStageName }.join(', ')
                    env.failedStage = failedNames ?: 'Shell Test Stage'
                } catch (Exception e) {
                    echo "Could not fetch failed stages: ${e.message}"
                    env.failedStage = 'Shell Test Stage'
                }
                sendNotification('FAILURE')
            }
        }
        always {
            cleanWs()
        }
    }
}