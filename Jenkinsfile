pipeline {
  agent { label 'master' }
  environment {
    liquibase = '/var/lib/jenkins/liquibase/liquibase'
  }
  stages {
    stage('liquibase') {
      steps {
        sh '${liquibase} --version'
      }
    }
  }
}
