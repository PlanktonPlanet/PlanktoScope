#!/bin/bash -eux
# The base OS tools enable basic operation of the OS, and provide generalized mechanisms for
# bootstrapping further software (e.g. user applications) to be installed afterwards.

config_files_root=$(dirname $(realpath $BASH_SOURCE))

# Install some tools for a nicer command-line experience over ssh
# Note: we don't want to do an apt-get upgrade because then we'd have no way to ensure the same set
# of package versions for existing packages if we run the script at different times.
sudo apt-get update -y
sudo apt-get install -y vim byobu git

# Install some tools for dealing with captive portals
sudo apt-get install -y w3m
# Browsh (which requires firefox-esr) can be used to ssh into a PlanktoScope and have it
# authenticate to a captive portal on the wifi network in order to get internet access.
sudo apt-get install -y firefox-esr
mkdir -p /home/pi/.local/bin
curl -L https://github.com/browsh-org/browsh/releases/download/v1.8.0/browsh_1.8.0_linux_armv7 \
  -o /home/pi/.local/bin/browsh

# Install Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y # get the list of packages from the docker repo
# The following command will fail with a post-install error if the system installed kernel updates
# via apt upgrade but was not rebooted before installing docker-ce; however, even if this error
# is reported, docker will work after reboot.
# Refer to https://www.reddit.com/r/raspberry_pi/comments/zblky6/comment/iytpp4g/ for details.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Set up Docker Swarm Mode
file="/etc/systemd/system/first-boot-docker-swarm.service"
sudo cp "$config_files_root$file" "$file"
sudo systemctl enable first-boot-docker-swarm.service

# Install cockpit
sudo apt-get update -y
sudo apt-get install -y cockpit
sudo mkdir -p /etc/cockpit/
file="/etc/cockpit/cockpit.conf"
sudo cp "$config_files_root$file" "$file"
