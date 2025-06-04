# CI Pipeline using Jenkins, SonarQube, Nexus & Slack

This project demonstrates a complete CI pipeline setup using Jenkins, integrated with SonarQube for code quality analysis, Nexus for artifact storage, and Slack for build notifications.

##  Tools Used
- Jenkins
- SonarQube
- Nexus Repository Manager
- Slack Webhook
- Maven
- GitHub

##  Pipeline Workflow
1. Jenkins pulls code from GitHub
2. Builds Java Maven project
3. Performs SonarQube analysis
4. Uploads artifact to Nexus
5. Sends notification to Slack

##  Project Structure
├── Jenkinsfile
├── pom.xml
├── src/
├── sonar-project.properties
├── README.md
└── screenshots/
