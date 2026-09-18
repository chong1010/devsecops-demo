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

  //environment {
    //deploymentName = "devsecops"
    //containerName = "devsecops-container"
    //serviceName = "devsecops-svc"
    //imageName = "siddharth67/numeric-app:${GIT_COMMIT}"
    //applicationURL="http://devsecops-demo.eastus.cloudapp.azure.com"
    //applicationURI="/increment/99"
  //}

  stages {

     stage('Build Artifact - Maven') {
       steps {
         sh "mvn clean package -DskipTests=true"
         archive 'target/*.jar'
       }
     }

     stage('Unit Tests - JUnit and JaCoCo') {
       steps {
         sh 'mvn test'
       }
		post {
		  always {
		  // Publish JUnit results
		  junit 'target/surefire-reports/*.xml'
		  // Publish JaCoCo coverage
		  jacoco execPattern: 'target/jacoco.exec', 
		         classPattern: 'target/classes', 
		         sourcePattern: 'src/main/java'
	      }
		} 
     }
	 stage('Docker Build and Push') {
            steps {
                withDockerRegistry(credentialsId: 'docker-hub', url: '') {
                    sh 'docker build -t chongchang/numeric-app:"$GIT_COMMIT" .'
                    sh 'docker push chongchang/numeric-app:"$GIT_COMMIT"'
                }
            }
        }
  }
}
