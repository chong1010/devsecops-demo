//@Library('slack') _


/////// ******************************* Code for fectching Failed Stage Name ******************************* ///////
import io.jenkins.blueocean.rest.impl.pipeline.PipelineNodeGraphVisitor
import io.jenkins.blueocean.rest.impl.pipeline.FlowNodeWrapper
import org.jenkinsci.plugins.workflow.support.steps.build.RunWrapper
import org.jenkinsci.plugins.workflow.actions.ErrorAction

// Get information about all stages, including the failure cases
// Returns a list of maps: [[id, failedStageName, result, errors]]
@NonCPS
List<Map> getStageResults( RunWrapper build ) {

    // Get all pipeline nodes that represent stages
    def visitor = new PipelineNodeGraphVisitor( build.rawBuild )
    def stages = visitor.pipelineNodes.findAll{ it.type == FlowNodeWrapper.NodeType.STAGE }

    return stages.collect{ stage ->

        // Get all the errors from the stage
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

/////// ******************************* Code for fectching Failed Stage Name ******************************* ///////

pipeline {
    agent any

    environment {
        // Centralized pipeline variables
        IMAGE_NAME   = "chongchang/numeric-app"
        IMAGE_TAG    = "${GIT_COMMIT}"
        SONAR_KEY    = "numeric-application"
        SONAR_NAME   = "numeric-application"
        K8S_MANIFEST = "k8s_deployment_service.yaml"
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
                    // Publish JUnit and JaCoCo coverage reports
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

        // MUST BUILD IMAGE BEFORE TRIVY SCAN
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

        stage('Kubernetes Policy Scan') {
            steps {
                sh '''
                    docker run --rm -v "${WORKSPACE}":/project \
                      openpolicyagent/conftest test \
                      --policy opa-k8s-security.rego k8s_deployment_service.yaml
                '''
            }
        }
        // PUSH ONLY AFTER TRIVY AND DEPENDENCY SCAN PASS
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
                    // Update manifest image tag dynamically and deploy
                    sh """
                        sed -i "s#replace#${IMAGE_NAME}:${IMAGE_TAG}#g" ${K8S_MANIFEST}
                        kubectl apply -f ${K8S_MANIFEST}
                    """
                }
            }
        }
    }

    post {
        always {
            // Clean local Docker image to prevent disk space issues on Vagrant VM
            sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            // Clean workspace build directory
            cleanWs()
        }
    }
}
