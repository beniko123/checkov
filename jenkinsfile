pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/YOUR_REPO/terraform-checkov-lab.git'
            }
        }

        stage('Install Checkov') {
            steps {
                sh '''
                pip3 install --upgrade checkov
                '''
            }
        }

        stage('Run Checkov Scan') {
            steps {
                sh '''
                checkov -d . --output cli
                '''
            }
        }
    }
}
