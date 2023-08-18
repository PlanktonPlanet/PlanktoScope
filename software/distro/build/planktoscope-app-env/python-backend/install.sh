#!/bin/bash -eux
# The Python backend provides a network API abstraction over hardware devices, as well as domain
# logic for operating the PlanktoScope hardware.

config_files_root=$(dirname $(realpath $BASH_SOURCE))

## Install basic Python tooling
sudo apt-get update -y
sudo apt-get install -y git python3-pip python3-venv

# Install Poetry
# Note: poetry 1.5.0 and above requires cryptography==40.0.2, which isn't available on piwheels and
# can't build properly on the Raspberry Pi OS's bullseye 2023-05-03 release. Poetry 1.4.2 only
# requires cryptography==39.0.1, according to its poetry.lock file
# (see https://github.com/python-poetry/poetry/blob/1.4.2/poetry.lock). Because the poetry
# installation process (whether with pipx or the official installer) always selects the most recent
# version of the cryptography dependency, we must instead do a manual poetry installation.
POETRY_VENV=/home/pi/.local/share/pypoetry/venv
mkdir -p $POETRY_VENV
python3 -m venv $POETRY_VENV
$POETRY_VENV/bin/pip install --upgrade pip==23.2.1 setuptools==68.1.0
$POETRY_VENV/bin/pip install cryptography==39.0.1
$POETRY_VENV/bin/pip install poetry==1.4.2
file="/home/pi/.local/bin/poetry"
cp "$config_files_root$file" "$file"
export PATH="/home/pi/.local/bin:$PATH"

# Install pipx (not required, but useful)
python3 -m pip install --user pipx==1.2.0
python3 -m pipx ensurepath

# Install Fan HAT dependencies
# FIXME: delete this commented section if we don't actually need it
# sudo apt install -y i2c-tools
# mkdir -p /home/pi/libraries
# FIXME: can we get a reproducible build of WiringPi? Or maybe just Python library support via pip?
# git clone https://github.com/WiringPi/WiringPi /home/pi/libraries/WiringPi
# cd into WiringPi's directory because WiringPi's build script only knows how to run from there
# cd /home/pi/libraries/WiringPi
# sudo /home/pi/libraries/WiringPi/build
# cd /home/pi

# Install Python dependencies
# FIXME: if we're not using libhdf5, libopenjp2-7, libopenexr25, libavcodec58, libavformat58, and
# libswscale5, can we avoid the need to install them? Right now they're required because the Python
# backend is doing an `import * from cv2`, which is wasteful and also pollutes the namespace - if we
# only import the required subpackages from cv2, maybe we can avoid the need to install unnecessary
# dependencies via apt-get?
sudo apt-get install -y libatlas3-base \
  libhdf5-103-1 libopenjp2-7 libopenexr25 libavcodec58 libavformat58 libswscale5
# TODO: pin this at a specific version (at least until we distribute it as a Docker image)
wget https://github.com/PlanktoScope/device-backend/archive/refs/heads/main.zip
unzip main.zip
rm main.zip
mv device-backend-main /home/pi/device-backend
cd /home/pi/device-backend
poetry install
cd /home/pi
