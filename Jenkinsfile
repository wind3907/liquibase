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
    stage('Status') {
      steps {
        sh '${liquibase} status --url="jdbc:oracle:thin:@lx739q3-db.swms-np.us-east-1.aws.sysco.net:1521:SWM1" --changeLogFile=./liquibase/root/db.changelog-root.xml --username="swms" --password="swms"'
      }
    }
    stage('Update') {
      steps {
        sh '${liquibase} update --url="jdbc:oracle:thin:@lx739q3-db.swms-np.us-east-1.aws.sysco.net:1521:SWM1" --changeLogFile=./liquibase/root/db.changelog-root.xml --username="swms" --password="swms"'
      }
    }
  }
  post {
    always {
      cleanWs()
    }
  }
}
