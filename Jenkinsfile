pipeline {
  agent none
  stages {
    stage('liquibase') {
      agent {
        docker { image 'liquibase/liquibase:latest' }
      }
      steps {
        sh 'liquibase --version'
      }
    }
  }
}
