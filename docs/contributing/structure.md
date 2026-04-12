---
title: Project Layout
parent: Contributing
nav_order: 2
---

# Project Layout

```text
.
├── .devcontainer
│   └── devcontainer.json
├── .github
│   ├── github workflows to build and update the Zwift container image
│   └── github workflow for linting
├── bin
│   └── install script and desktop icon
├── docs
│   └── jekyll documentation site
├── src
│   ├── Dockerfile
│   ├── build-image.sh                     Build the Zwift container image
│   ├── zwift-auth.sh                      Helper script to authenticate using the Zwift API
│   ├── run_zwift.sh                       Launch Zwift inside the container
│   ├── update_zwift.sh                    Update or install Zwift inside the container
│   ├── entrypoint.sh                      Runs when the container launches, invokes run or update
│   └── zwift.sh                           Launch the Zwift container
├── tests
│   └── test for nix flake
├── linter config files
├── flake.nix
├── LICENSE
└── README.md
```
