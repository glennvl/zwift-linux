#!/usr/bin/env bash
set -euo pipefail

if ! docker info > /dev/null 2>&1; then
    sudo update-alternatives --set iptables /usr/sbin/iptables-nft
fi

npm install -g markdownlint-cli2 cspell

gem update --system
gem install bundler
