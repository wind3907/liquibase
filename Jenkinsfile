pipeline {
  agent { label 'master' }
  stages {
    stage('liquibase') {
      steps {
        sh 'liquibase --version'
      }
    }
    stage('JAVA') {
      steps {
        sh '$JAVA_HOME'
      }
    }
  }
}
