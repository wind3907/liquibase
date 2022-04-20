pipeline {
  agent {
    docker { image 'liquibase/liquibase:latest' }
  }
//   environment {
//     URL='jdbc:oracle:thin:@lx739q3-db.swms-np.us-east-1.aws.sysco.net:1521:SWM1'
//   }
  stages {
    stage('test') {
      sh 'java --version'
      echo 'java home'
      echo $JAVA_HOME
      echo 'path'
      echo $PATH
    }
//     stage('Status') {
//       steps {
//         sh 'liquibase status --log-level info --url="jdbc:oracle:thin:@lx739q3-db.swms-np.us-east-1.aws.sysco.net:1521:SWM1" --changeLogFile=./liquibase/root/db.changelog-root.xml --username="swms" --password="swms"'
//       }
//     }
//     stage('Update') {
//       steps {
//         sh 'liquibase update --url="jdbc:oracle:thin:@lx739q3-db.swms-np.us-east-1.aws.sysco.net:1521:SWM1" --changeLogFile=./liquibase/root/db.changelog-root.xml --username="swms" --password="swms"'
//       }
//     }
  }
  post {
    always {
      cleanWs()
    }
  }
}
