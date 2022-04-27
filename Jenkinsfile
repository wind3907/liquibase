pipeline {
  agent { label 'master' }
  stages {
    stage('liquibase') {
      steps {
        sh '/var/lib/jenkins/liquibase/liquibase --version'
      }
    }
  }
}
