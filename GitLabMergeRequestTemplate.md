# Merge Request Template

## Summary

Describe the change and why it is needed.

## Checklist - Please check applicable items for release type

- [ ] Branch is up to date with the target branch and has no commits behind.
- [ ] Target branch is correct for environment deployment.
- [ ] Required approvals have been requested:
  - [ ] `develop`: 1 approval
  - [ ] `release/*`: 2 approvals, including Operations
  - [ ] `main`: 3 approvals, including Cyber, Architecture, and Test Manager
- [ ] CI pipeline is green and required checks are passing.
- [ ] Ticket/issue link is included.
- [ ] Environment impact is documented.
- [ ] Production deployment from `main` is tagged using the format `main-V<date>-versionNumberForThatDay` for traceability and multi-version support.
- [ ] Rollback plan or mitigation steps are documented.
- [ ] Terraform versions have been updated to latest version available that supports this deployment.

## Deployment Notes

Describe any deployment steps or special environment configuration.
### Example special environment configuration:
  Prior to deploying the pipeline, the NVA must be shut down, example configuration removed, and NVA turned back on.
  Once pipeline is deployed the NVA must be shut down, configuration added back, and NVA turned back on.

## Testing

Describe the testing performed and the results.

## Reviewers

- [ ] Test Manager
- [ ] Cyber
- [ ] Architecture
- [ ] Operations
