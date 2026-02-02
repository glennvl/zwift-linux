#!/usr/bin/env bash
set -euo pipefail

# TODO install depandapont through nix flake
go install github.com/dependabot/cli/cmd/dependabot@latest
