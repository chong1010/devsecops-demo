@Library('slack') _

import io.jenkins.blueocean.rest.impl.pipeline.PipelineNodeGraphVisitor
import io.jenkins.blueocean.rest.impl.pipeline.FlowNodeWrapper
import org.jenkinsci.plugins.workflow.support.steps.build.RunWrapper
import org.jenkinsci.plugins.workflow.actions.ErrorAction

// Get information about all stages, including failure cases
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

    options {
        buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5'))
    }

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
                    },
                    'CIS Kube-bench Scan': {
                        withKubeConfig([credentialsId: 'kubeconfig']) {
                            sh 'bash cis-kubelet.sh'
                        }
                    }
                )
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
    }

    // --- PIPELINE-LEVEL POST BLOCK (Option 1) ---
    post {
        success {
            script {
                sendNotification('SUCCESS')
            }
        }
        unstable {
            script {
                sendNotification('UNSTABLE')
            }
        }
        failure {
            script {
                try {
                    def failedStagesList = getFailedStages(currentBuild)
                    def failedNames = failedStagesList.collect { it.failedStageName }.join(', ')
                    env.failedStage = failedNames ?: 'Unknown Failure Stage'
                } catch (Exception e) {
                    env.failedStage = 'Build Failed'
                }
                sendNotification('FAILURE')
            }
        }
        always {
            // Archives Trivy and Kube-bench JSON reports at the end of the entire build
            archiveArtifacts artifacts: "${TRIVY_REPORT}, kube-bench-report.json", allowEmptyArchive: true

            // Clean workspace and remove temporary docker images
            sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            cleanWs()
        }
    }
}