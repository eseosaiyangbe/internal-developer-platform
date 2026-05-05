## MemFlip Pilot Extraction

This document records the first managed workload extraction from the current
platform workspace into its own repository.

### Purpose

`MemFlip` is the pilot workload for the repository split because it is the
lowest-risk extraction candidate among the managed workloads.

### Source Of Truth

The authoritative source for this extraction is:

`/Users/raymond/Documents/DevOps-Easy-Learning/MemFlip`

The pre-existing GitHub child repository was determined to be stale and is not
used as an input source for the extraction.

### Extraction Rules

- preserve application history from the current platform workspace
- do not merge stale child-repo structure back into the active workload
- remove tracked local-only environment files from the extracted repository
- preserve the current owned Kubernetes path, scripts, docs, and application code

### Current Pilot Outcome

The intended target child repository is:

`https://github.com/eseosaiyangbe/MemFlip`

The extraction strategy is:

1. clean the workload boundary
2. create a history-preserving subtree split from `MemFlip/`
3. force-update the child repository from the extracted authoritative history

### Transition Note

`MemFlip` is the first workload targeted for physical removal from the current
platform workspace after the sibling-checkout model was proven.

The workspace remains the central coordination repo while the broader
multi-repository migration continues.
