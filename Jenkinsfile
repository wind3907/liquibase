pipeline {
  agent any
  stages {
    stage('liquibase') {
      steps {
        export PATH=$PATH:/var/lib/jenkins/liquibase
        sh 'liquibase --version'
      }
    }
  }
}
