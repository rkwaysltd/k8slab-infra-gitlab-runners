// this file has the baseline default parameters
{
  components: {
    runner: {
      // Manager pod namespace
      namespace: 'ci-runners',
      // Executor pods namespace
      jobNamespace: 'ci-jobs',
      runnerTemplateValues: {
        common: {
          // Default Docker image to run in job if none specified
          // sha256:0f354ec1728d9ff32edcd7d1b8bbdfc798277ad36120dc3dc683be44524c8b60 is busybox:1.33.1
          //
          defaultBuildImage: 'busybox@sha256:0f354ec1728d9ff32edcd7d1b8bbdfc798277ad36120dc3dc683be44524c8b60',
          // Resources limits/requests
          //
          // - build container
          build_cpu_limit: '200m',
          build_cpu_request: '100m',
          build_memory_limit: '256Mi',
          build_memory_request: '128Mi',
          // - helper container
          helper_cpu_limit: '200m',
          helper_cpu_request: '100m',
          helper_memory_limit: '256Mi',
          helper_memory_request: '128Mi',
          // - service container
          service_cpu_limit: '200m',
          service_cpu_request: '100m',
          service_memory_limit: '256Mi',
          service_memory_request: '128Mi',
        },
        arm64: {
          // Helper container image
          helperImage: 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:arm64-${CI_RUNNER_REVISION}',
        },
        amd64: {
          // Helper container image
          helperImage: 'registry.gitlab.com/gitlab-org/gitlab-runner/gitlab-runner-helper:x86_64-${CI_RUNNER_REVISION}',
        },
      },
      helmValues: {
        // The GitLab Server URL (with protocol) that want to register the runner against
        // ref: https://docs.gitlab.com/runner/commands/README.html#gitlab-runner-register
        //
        gitlabUrl: 'https://gitlab.com/',

        // Configure the maximum number of concurrent jobs
        // ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
        //
        concurrent: 2,

        // Defines in seconds how often to check GitLab for a new builds
        // ref: https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-global-section
        //
        checkInterval: 30,

        // Configure resource requests and limits for manager pod
        resources: {
          limits: {
            memory: '256Mi',
            cpu: '200m',
          },
          requests: {
            memory: '128Mi',
            cpu: '100m',
          },
        },
      },
    },
  },
}
