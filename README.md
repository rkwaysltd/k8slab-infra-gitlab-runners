# gitlab-runners

Installs Gitlab runners (unprivileged) in the cluster.

# Gitlab CI variables

- `GITLAB_RUNNER_TOKEN` (type: Variable, protected, masked) - Gitlab Runner token

# TODO

- move job pods to separate namespace
- create unpriv SA for job pods
- more params in runnerConfig
