#!/bin/bash

# Install dependencies (Java 11 and wget)
yum install java-17-openjdk.x86_64 wget -y

# Create necessary directories for Nexus and sonatype-work
mkdir -p /opt/nexus/
mkdir -p /opt/sonatype-work/

# Download and extract the latest Nexus version
cd /tmp/
NEXUSURL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
wget $NEXUSURL -O nexus.tar.gz
if [ $? -ne 0 ]; then
  echo "Failed to download Nexus. Exiting."
  exit 1
fi

# Extract Nexus and get the directory name after extraction
tar xzvf nexus.tar.gz -C /opt/nexus/ --strip-components=1
if [ $? -ne 0 ]; then
  echo "Failed to extract Nexus. Exiting."
  exit 1
fi

# Create the nexus user if not already created
if ! id -u nexus > /dev/null 2>&1; then
  useradd nexus
fi

# Change ownership of the Nexus directory and sonatype-work to the nexus user
chown -R nexus:nexus /opt/nexus /opt/sonatype-work

# Create systemd service for Nexus
cat <<EOT > /etc/systemd/system/nexus.service
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

# Configure Nexus to run as the nexus user
echo 'run_as_user="nexus"' > /opt/nexus/bin/nexus.rc

# Reload systemd to recognize the new Nexus service
systemctl daemon-reload

# Start and enable Nexus service
systemctl start nexus
systemctl enable nexus

# Ensure the service starts on reboot
systemctl is-active nexus && echo "Nexus is running!" || echo "Nexus failed to start."
