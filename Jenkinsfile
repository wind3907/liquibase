pipeline {
  agent { label 'master' }
  stages {
    stage('liquibase') {
      steps {
        sh 'liquibase --version'
      }
    }
  }
}
