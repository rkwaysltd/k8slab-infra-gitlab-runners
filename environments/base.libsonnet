// this file has the baseline default parameters
{
  components: {
    runner: {
      namespace: 'ci-runners',
      defaultBuildImage: 'sha256:c5439d7db88ab5423999530349d327b04279ad3161d7596d2126dfb5b02bfd1f',
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
