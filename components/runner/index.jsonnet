local p = import '../../params.libsonnet';
local params = p.components.runner;
local k = import 'k8slab-kube-libsonnet/kube.libsonnet';
local k8slab = import 'k8slab-kube-libsonnet/k8slab.libsonnet';

local gitlabRunnerNamespace = k.Namespace(params.namespace);

// Kubernetes executor configuration
local runnersConfig = {
  common: {
    defaultBuildImage: params.runnerTemplateValues.defaultBuildImage,
    pruneKey: std.extVar('rkways.com/prune-key'),
    appLabel: k8slab.name() + '-ci-job',
  },
  arm64: self.common {
    arch: 'arm64',
    helperImage: params.runnerTemplateValues.helperImageArm64,
  },
  amd64: self.common {
    arch: 'amd64',
    helperImage: params.runnerTemplateValues.helperImageAmd64,
  },
  tmpl: |||
    [[runners]]
      ## Feature flags for Runner
      ## - FF_GITLAB_REGISTRY_HELPER_IMAGE - the runner will pull the image from registry.gitlab.com
      ##   https://docs.gitlab.com/runner/configuration/advanced-configuration.html#migrating-helper-image-to-registrygitlabcom
      ##
      environment = ["FF_GITLAB_REGISTRY_HELPER_IMAGE=1"]

      [runners.kubernetes]
      ## Default container image to use for builds when none is specified
      ##
      image = "%(defaultBuildImage)s"

      ## Run all containers with the privileged flag enabled
      ## This will allow the docker:stable-dind image to run if you need to run Docker
      ## commands. Please read the docs before turning this on:
      ## ref: https://docs.gitlab.com/runner/executors/kubernetes.html#using-docker-dind
      ##
      privileged = false

      ## Service Account to be used for runners
      ##
      #service_account = "gitlab-runner-infra-clusteradmin"

      ## Namespace to run Kubernetes jobs in (defaults to 'default')
      ##
      #namespace = "infra"

      ## The CPU allocation given to/requested for build containers
      ##
      cpu_limit = "200m"
      cpu_request = "100m"

      ## The CPU allocation given to/requested for build helper containers
      ##
      helper_cpu_limit = "200m"
      helper_cpu_request = "100m"

      ## The CPU allocation given to/requested for build service containers
      ##
      service_cpu_limit = "200m"
      service_cpu_request = "100m"

      ## The amount of memory allocated to/requested from build containers
      ##
      memory_limit = "256Mi"
      memory_request = "128Mi"

      ## The amount of memory allocated to/requested from build helper containers
      ##
      helper_memory_limit = "256Mi"
      helper_memory_request = "128Mi"

      ## The amount of memory allocated to/requested from build service containers
      ##
      service_memory_limit = "256Mi"
      service_memory_request = "128Mi"

      ## Helper container image
      ##
      helper_image = "%(helperImage)s"

      ## Specify node labels for CI job pods assignment
      ## ref: https://kubernetes.io/docs/concepts/configuration/assign-pod-node/
      ##
      [runners.kubernetes.node_selector]
        "kubernetes.io/arch" = "%(arch)s"

      ## Specify pod labels for CI job pods
      ##
      [runners.kubernetes.pod_labels]
        "rkways.com/prune-key" = "%(pruneKey)s"
        "app" = "%(appLabel)s"
  |||,
  textArm64: self.tmpl % self.arm64,
  textAmd64: self.tmpl % self.amd64,
};

local gitlabRunnerHelm = std.native('expandHelmTemplate')(
  '../../helm/gitlab-runner-%s.tgz' % std.extVar('CHART_VERSION'),
  params.helmValues {
    // The registration token for adding new Runners to the GitLab server. This must
    // be retrieved from your GitLab instance.
    // ref: https://docs.gitlab.com/ee/ci/runners/
    //
    runnerRegistrationToken: std.extVar('GITLAB_RUNNER_TOKEN'),

    // RBAC
    rbac: {
      create: true,
    },

    // Configuration
    runners: {
      config: runnersConfig.textArm64 + runnersConfig.textAmd64,
    },
  },
  {
    nameTemplate: k8slab.name(),
    namespace: gitlabRunnerNamespace.metadata.name,
    thisFile: std.thisFile,
    verbose: true,
  }
);

[gitlabRunnerNamespace] + gitlabRunnerHelm
