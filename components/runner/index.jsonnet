local p = import '../../params.libsonnet';
local params = p.components.runner;
local k = import 'k8slab-kube-libsonnet/kube.libsonnet';
local k8slab = import 'k8slab-kube-libsonnet/k8slab.libsonnet';

// Same as many objects in rendered Helm
local longName = k8slab.name() + '-gitlab-runner';

local gitlabRunnerNamespace = k.Namespace(params.namespace);
local gitlabRunnerServiceAccount = k.ServiceAccount(longName) {
  metadata+: {
    namespace: gitlabRunnerNamespace.metadata.name,
  },
};
local gitlabRunnerJobNamespace = k.Namespace(params.jobNamespace);
local gitlabRunnerRole = k.Role(longName) {
  metadata+: {
    namespace: gitlabRunnerJobNamespace.metadata.name,
  },
  rules: [{
    apiGroups: [''],
    resources: ['pods', 'secrets'],
    verbs: ['get', 'list', 'watch', 'create', 'patch', 'delete'],
  }, {
    apiGroups: [''],
    resources: ['pods/exec', 'pods/attach'],
    verbs: ['get', 'create'],
  }],
};
local gitlabRunnerRoleBinding = k.RoleBinding(longName) {
  metadata+: {
    namespace: gitlabRunnerJobNamespace.metadata.name,
  },
  roleRef_: gitlabRunnerRole,
  subjects_+: [gitlabRunnerServiceAccount],
};

// Kubernetes executor configuration
local runnersConfig = {
  common: params.runnerTemplateValues.common {
    tags+: ['arch-any', 'arch-%s' % self.arch],
    tagList: std.join(',', self.tags),
    pruneKey: std.extVar('rkways.com/prune-key'),
    appLabel: k8slab.name() + '-ci-job',
    jobNamespace: gitlabRunnerJobNamespace.metadata.name,
  },
  arm64: self.common + params.runnerTemplateValues.arm64 {
    arch: 'arm64',
    configMapEntry: 'config.template.arm64.toml',
  },
  amd64: self.common + params.runnerTemplateValues.amd64 {
    arch: 'amd64',
    configMapEntry: 'config.template.amd64.toml',
  },
  configTmpl: |||
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
      #service_account = "default"

      ## Namespace to run Kubernetes jobs in (defaults to 'default')
      ##
      namespace = "%(jobNamespace)s"

      ## The CPU allocation given to/requested for build containers
      ##
      cpu_limit = "%(build_cpu_limit)s"
      cpu_request = "%(build_cpu_request)s"

      ## The CPU allocation given to/requested for build helper containers
      ##
      helper_cpu_limit = "%(helper_cpu_limit)s"
      helper_cpu_request = "%(helper_cpu_request)s"

      ## The CPU allocation given to/requested for build service containers
      ##
      service_cpu_limit = "%(service_cpu_limit)s"
      service_cpu_request = "%(service_cpu_request)s"

      ## The amount of memory allocated to/requested from build containers
      ##
      memory_limit = "%(build_memory_limit)s"
      memory_request = "%(build_memory_request)s"

      ## The amount of memory allocated to/requested from build helper containers
      ##
      helper_memory_limit = "%(helper_memory_limit)s"
      helper_memory_request = "%(helper_memory_request)s"

      ## The amount of memory allocated to/requested from build service containers
      ##
      service_memory_limit = "%(service_memory_limit)s"
      service_memory_request = "%(service_memory_request)s"

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
};

local gitlabRunnerHelmRender = k8slab.arrayByKindAndName(std.native('expandHelmTemplate')(
  '../../helm/gitlab-runner-%s.tgz' % std.extVar('CHART_VERSION'),
  params.helmValues {
    // The registration token for adding new Runners to the GitLab server. This must
    // be retrieved from your GitLab instance.
    // ref: https://docs.gitlab.com/ee/ci/runners/
    //
    runnerRegistrationToken: std.extVar('GITLAB_RUNNER_TOKEN'),

    // RBAC
    rbac: {
      create: false,
      serviceAccountName: gitlabRunnerServiceAccount.metadata.name,
    },

    runners: {
      // Single config template not good enough
      config: '# check config.template.*.toml entries',
    },
  },
  {
    nameTemplate: k8slab.name(),
    namespace: gitlabRunnerNamespace.metadata.name,
    thisFile: std.thisFile,
    verbose: true,
  }
));

local gitlabRunnerHelm = k8slab.arrayFromKindAndName(gitlabRunnerHelmRender {
  local registerCmd = 'CONFIG_TEMPLATE_K8SLAB="%(configMapEntry)s" RUNNER_TAG_LIST="%(tagList)s" sh /configmaps/register-the-runner-k8slab',
  ConfigMap+: {
    [longName]+: {
      data+: {
        // Multiple configuration templates
        [runnersConfig.arm64.configMapEntry]: runnersConfig.configTmpl % runnersConfig.arm64,
        [runnersConfig.amd64.configMapEntry]: runnersConfig.configTmpl % runnersConfig.amd64,
        // Custom registration procedure
        'register-the-runner': '#!/bin/bash\nexit 0\n',
        // Patched registration script
        'register-the-runner-k8slab': std.strReplace(
          gitlabRunnerHelmRender.ConfigMap[longName].data['register-the-runner'],
          '/configmaps/config.template.toml',
          '/configmaps/${CONFIG_TEMPLATE_K8SLAB}',
        ),
        'pre-entrypoint-script': std.join('\n', [
          '#!/bin/bash',
          registerCmd % runnersConfig.arm64,
          registerCmd % runnersConfig.amd64,
        ]),
      },
    },
  },
});

[gitlabRunnerNamespace, gitlabRunnerServiceAccount, gitlabRunnerJobNamespace, gitlabRunnerRole, gitlabRunnerRoleBinding] + gitlabRunnerHelm
