// this file has the param overrides for the k8slab environment
local base = import './base.libsonnet';

base {
  components+: {
    runner+: {
      runnerTemplateValues+: {
        common+: {
          // Resources limits/requests
          //
          // - build container
          build_cpu_limit: '4000m',
          build_cpu_request: '250m',
          build_memory_limit: '3Gi',
          build_memory_request: '1Gi',
        },
      },
      helmValues+: {
        // Node labels for pod assignment (gitlab runner manager)
        //
        // Place runner on Raspberry Pi
        nodeSelector+: {
          'kubernetes.io/arch': 'arm64',
        },
      },
    },
  },
}
