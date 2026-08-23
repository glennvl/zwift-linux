#!/usr/bin/env bash
set -euo pipefail

npm install -g markdownlint-cli2 cspell

gem update --system
gem install bundler

go install github.com/dependabot/cli/cmd/dependabot@latest
