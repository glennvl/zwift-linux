---
title: Dependabot
parent: Development Environment
nav_order: 4
---

# Dependabot

Check if there are updates available for external dependencies.

```console
foo@bar:~$ dependabot update bundler netbrain/zwift --local . --directory docs
foo@bar:~$ dependabot update docker netbrain/zwift --local . --directory src
foo@bar:~$ dependabot update github_actions netbrain/zwift --local .
foo@bar:~$ dependabot update nix netbrain/zwift --local .
```
