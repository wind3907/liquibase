pipeline {
  agent { label 'master' }
  stages {
    stage('liquibase') {
      steps {
        sh 'liquibase --version'
      }
    }
    stage('Android') {
      steps {
        sh '$ANDROID_HOME'
      }
    }
  }
}
