#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
	fonts-ipafont-gothic \
	fonts-ipafont-mincho \
	libnss3-tools \
	locales
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
sudo fc-cache -f

bash .devcontainer/setup-browser-menu.sh