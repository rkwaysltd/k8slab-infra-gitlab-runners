// this file has the param overrides for the k8slab environment
local base = import './base.libsonnet';

base {
  components+: {
    runner+: {
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
