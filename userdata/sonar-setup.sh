#!/bin/bash

# Backup configuration files
cp /etc/sysctl.conf /root/sysctl.conf_backup
cp /etc/security/limits.conf /root/sec_limit.conf_backup

# Update system settings
cat <<EOT > /etc/sysctl.conf
vm.max_map_count=262144
fs.file-max=65536
EOT

cat <<EOT > /etc/security/limits.conf
sonarqube   -   nofile   65536
sonarqube   -   nproc    4096
EOT

# Apply sysctl settings
sysctl -p

# Update package list
sudo apt-get update -y

# Install Java (OpenJDK 17 is recommended for SonarQube)
sudo apt-get install openjdk-17-jdk -y

# Set default Java version
sudo update-alternatives --config java <<< 1
java -version

# Install PostgreSQL and required packages
sudo apt-get install wget gnupg -y
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install postgresql postgresql-contrib -y

# Start PostgreSQL service
sudo systemctl enable postgresql.service
sudo systemctl start postgresql.service

# Configure PostgreSQL user and database for SonarQube
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Install SonarQube
sudo mkdir -p /sonarqube/
cd /sonarqube/
sudo curl -O https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.7.0.61503.zip
sudo apt-get install zip -y
sudo unzip -o sonarqube-9.7.0.61503.zip -d /opt/
sudo mv /opt/sonarqube-9.7.0.61503/ /opt/sonarqube

# Determine architecture and set correct paths
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    SONAR_BIN_DIR="linux-x86-64"
elif [[ "$ARCH" == "aarch64" ]]; then
    SONAR_BIN_DIR="linux-aarch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Create SonarQube user and set permissions
sudo groupadd sonar
sudo useradd -c "SonarQube - User" -d /opt/sonarqube/ -g sonar sonar
sudo chown sonar:sonar /opt/sonarqube/ -R

# Update SonarQube configuration
cp /opt/sonarqube/conf/sonar.properties /root/sonar.properties_backup
cat <<EOT > /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
sonar.web.javaAdditionalOpts=-server
sonar.search.javaOpts=-Xmx512m -Xms512m -XX:+HeapDumpOnOutOfMemoryError
sonar.log.level=INFO
sonar.path.logs=logs
EOT

# Set up SonarQube systemd service
cat <<EOT > /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/$SONAR_BIN_DIR/sonar.sh start
ExecStop=/opt/sonarqube/bin/$SONAR_BIN_DIR/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd and enable SonarQube service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube.service

# Install Nginx
sudo apt-get install nginx -y

# Remove default Nginx configuration
sudo rm -rf /etc/nginx/sites-enabled/default
sudo rm -rf /etc/nginx/sites-available/default

# Create Nginx configuration for SonarQube
cat <<EOT > /etc/nginx/sites-available/sonarqube
server {
    listen 80;
    server_name sonarqube.yourdomain.com;

    access_log /var/log/nginx/sonar.access.log;
    error_log /var/log/nginx/sonar.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto http;
    }
}
EOT

# Enable Nginx configuration and restart Nginx
sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
sudo systemctl enable nginx.service
sudo systemctl restart nginx.service

# Open firewall ports for HTTP and SonarQube
sudo ufw allow 80,9000,9001/tcp

# Start SonarQube service
sudo systemctl start sonarqube.service
sudo systemctl status sonarqube.service
## IF NOT Run Please Chek the it's done installation or not 