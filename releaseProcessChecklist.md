# Release Checklist

Version: 1.0

Last updated: 2026-07-22

Purpose
-------

Provide a standardized checklist for planning, validating, communicating, deploying, and reviewing releases. This checklist is derived from the release process and is intended to ensure consistency, reduce risk, and support repeatable release execution.

This is a living document and should be updated as the release process evolves.

Release Planning
----------------

- [ ] Confirm release scope, objectives, and impacted services.
- [ ] Document release benefits, business value, and compliance impact.
- [ ] Capture historical context for similar releases and why the current process is preferred (Please reference the release process document lines 60 and 61 for more information.)
- [ ] Identify dependencies, integration points, and environment targets.
- [ ] Prepare the release plan, deployment runbook, and rollback plan.
- [ ] Create or update architecture, deployment flow, and rollback diagrams where needed.
- [ ] Identify and document risks, mitigation actions, and owners.
- [ ] Confirm stakeholder contacts and escalation paths.

Validation and Approvals
------------------------

- [ ] Run automated tests, linting, and validation checks.
- [ ] Complete security scans, compliance checks, and vulnerability reviews.
- [ ] Verify that all required code reviews are complete.
- [ ] Collect approvals from release manager, QA, security, and operations.
- [ ] Confirm the change is ready for the target environment.
- [ ] Ensure all approval and checklist status items are documented.

Communication
-------------

- [ ] Send a release notification with scope, schedule, and expected impact.
- [ ] Share the pre-release readiness status and any open risk items.
- [ ] Confirm the approved maintenance window and deployment window.
- [ ] Provide incident and escalation contacts to the release team and stakeholders.
- [ ] Verify that stakeholders understand rollback criteria and recovery steps.

Deployment Readiness
--------------------

- [ ] Confirm the deployment runbook is available and reviewed.
- [ ] Validate that the target environment is ready for deployment.
- [ ] Ensure monitoring, alerting, and health checks are configured.
- [ ] Confirm any required feature flags, configuration changes, or infrastructure updates are prepared.
- [ ] Verify that the release branch or tag is correct and up to date.

Deployment Execution
--------------------

- [ ] Start the deployment and notify stakeholders.
- [ ] Follow the deployment runbook step-by-step.
- [ ] Monitor progress, logs, alerts, and health checks during deployment.
- [ ] Validate the deployment with automated checks and manual verification.
- [ ] Document any deviations, issues, or unexpected behavior.

Rollback and Recovery
---------------------

- [ ] Confirm rollback criteria are understood and agreed.
- [ ] Ensure rollback steps are documented and accessible.
- [ ] If rollback is required, execute it promptly and communicate clearly.
- [ ] Validate system health after rollback and confirm success.

Post-Release Review
-------------------

- [ ] Notify stakeholders that the release is complete.
- [ ] Document the release outcome, issues, and improvement actions.
- [ ] Update the post-release report and risk register.
- [ ] Capture lessons learned and identify process improvements.
- [ ] Review the release process and update this checklist as needed.
