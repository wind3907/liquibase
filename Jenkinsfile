pipeline {
  agent none
  stages {
    stage('Run Tests') {
      parallel {
        stage("liquibase") {
          agent {
            docker { image 'liquibase/liquibase:latest' }
          }
          steps {
            stage('test') {
              steps {
                sh 'liquibase --version'
              }
            }
          }
        }
      }
    }
  }
}
