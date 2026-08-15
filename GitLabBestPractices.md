# GitLab Best Practices

Version: 1.0

Last updated: 2026-07-22

Purpose
-------

Document recommended GitLab practices for repository management, CI/CD, security, and authentication. This is a living document and will be updated over time as new GitLab features, security guidance, and integration patterns are adopted.

Scope
-----

- GitLab project and repository configuration.
- CI/CD pipeline security and secrets handling.
- Merge request and branch protection practices.
- Authentication and cloud credential management.

Security and Authentication (Future Implementation)
--------------------------------------------------

- Prioritize secure credential management for GitLab CI/CD pipelines.
- Use GitLab CI/CD variables and protected variables for secrets, and avoid storing credentials in repository code or pipeline definitions.
- Favor short-lived, cloud-managed credentials over long-lived service principals.
- Evaluate OpenID Connect (OIDC) integration for Azure to retrieve temporary credentials from GitLab.
- Future implementation item: configure OpenID Connect in Azure to retrieve temporary credentials from GitLab when running CI jobs.
  - Reference: [Configure OpenID Connect in Azure to retrieve temporary credentials | GitLab Docs](https://docs.gitlab.com/ci/cloud_services/azure/)

Branch and Merge Request Best Practices
---------------------------------------

- Protect main and release branches with required approvals and status checks.
- Use descriptive branch names aligned with the branching strategy.
- Require merge requests to include issue/ticket links, environment impact, and rollback guidance.
- Keep merge requests small and focused to reduce review time and risk.

CI/CD Pipeline Best Practices
-----------------------------

- Keep CI jobs modular and clearly scoped: build, test, security, deploy.
- Enforce pipeline quality with linting, static analysis, and security scans.
- Include SAST checks in every pipeline to identify application-level vulnerabilities before merge.
- Any suppression of SAST findings must be documented in a written exception, approved by the appropriate security owner, and stored in the repository alongside the Terraform code.
- Add secret detection and credential exposure scanning to prevent leaks from code, configuration, and CI job logs.
- Use KICS or equivalent infrastructure-as-code scanning for Terraform, Kubernetes manifests, and cloud templates.
- Add dependency scanning for application packages and container images as a complement to SAST.
- Ensure CI pipelines do not expose secrets in output: mask variables, avoid printing sensitive values, and use protected variables for production credentials.
- All modules and root deployment repositories should include a pipeline that performs:
  - code validation,
  - security checks, and
  - secret detection.
- Note: on occasion some modules cannot include validation due to the nature of the module. When that occurs, document the exception and still ensure security scanning and secret detection are applied where possible.
- Define whether failed validation, security, or secret-detection checks block merge and require remediation before deploy.
- Use `rules` to run jobs only for relevant branches and tags.
- Capture build metadata (branch, commit, tag, pipeline ID) in artifacts and logs for traceability.
  - Use GitLab predefined variables such as `CI_COMMIT_BRANCH`, `CI_COMMIT_SHA`, `CI_COMMIT_TAG`, `CI_PIPELINE_ID`, and `CI_PIPELINE_URL`.
  - Add steps to an existing build or validation job that:
    1. writes metadata values to the job log,
    2. creates a `metadata/build-metadata.txt` file,
    3. publishes that file as an artifact,
    4. retains the artifact long enough for debugging and audit review.
  - Example:

```yaml
build_metadata:
  stage: validate
  script:
    - echo "Branch=$CI_COMMIT_BRANCH"
    - echo "Commit=$CI_COMMIT_SHA"
    - echo "Tag=$CI_COMMIT_TAG"
    - echo "Pipeline=$CI_PIPELINE_ID"
    - mkdir -p metadata
    - cat > metadata/build-metadata.txt <<'EOF'
Branch: $CI_COMMIT_BRANCH
Commit: $CI_COMMIT_SHA
Tag: $CI_COMMIT_TAG
Pipeline: $CI_PIPELINE_ID
Pipeline URL: $CI_PIPELINE_URL
EOF
  artifacts:
    paths:
      - metadata/build-metadata.txt
    expire_in: 1 week
```
  - Optionally include metadata in other build outputs such as container labels, binary version files, or deployment manifests.
- Use policy-as-code or GitLab push rules where appropriate to enforce repository security guardrails.
  - Define the guardrails as a repeatable process, for example by including a shared template that requires branch protection, status checks, and merge approval policies.
  - Configure GitLab push rules or project-level protected branch settings to reject insecure commits, unauthorized force-pushes, and disallowed branch names.
    - In GitLab, go to `Settings` > `Repository` > `Push Rules` and add rules for commit message patterns, blocked file names, or denied author emails.
    - Use push rules to deny force pushes, prevent commits to protected branches, and require signed commits where available.
    - Use `Protected Branches` in `Settings` > `Repository` to restrict who can push, merge, or create tags on branches such as `main`, `release/*`, and `rc-main/*`.
    - Require status checks and approvals on protected branches by enabling merge request approvals and setting `Allow to merge` only for approvers.
  - Use GitLab security policy features or a policy-as-code repository when available to version and review guardrails alongside pipeline definitions.
  - Ensure the metadata capture job itself is protected by the same branch rules and merge policies used for the pipeline.

Standard shared pipelines
-------------------------

- Standardize pipelines in a central repository or shared templates project.
- Reference shared pipeline templates from source projects using `include`, so every repository can reuse the same baseline jobs and security checks.
- Example:
  ```yaml
  include:
    - project: 'group/gitlab-ci-templates'
      file: '/templates/standard-pipeline.yml'
  ```
- Use a minimal per-repo wrapper pipeline to configure repository-specific variables, stages, and overrides.
- Pin shared templates to a tag or commit to control changes and avoid unexpected pipeline drift.
- Define the shared pipeline contract: what jobs are required and what wrapper pipelines may override.
- Allow originating module pipelines to override validation in documented cases, while preserving common security and secret-detection jobs.
- Document exceptions when validation is suppressed, including the reason, owner, and periodic review date.

Shared pipeline contract
------------------------

- Required stages: `validate`, `security`, `plan`, `verify`, `deploy`.
- Required jobs: code validation, SAST, secret detection, and deployment planning.
- Shared pipeline outputs should include scan reports, validation artifacts, and metadata for traceability.
- Originating modules may override the `validate` stage only when documented exceptions exist; wrapper pipelines should not suppress validation unless the module itself requires it.
- Wrapper pipelines may add repository-specific deploy jobs, environment variables, and notifications.
- Shared templates should be referenced by tag or commit and reviewed before a version bump.

Sample shared pipeline
----------------------

The shared pipeline should include validation, security scanning, and secret detection jobs, for example:

```yaml
stages:
  - validate
  - security
  - plan
  - verify
  - deploy

validate:
  stage: validate
  script:
    - echo "Run code validation"
    - ./scripts/validate.sh
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(develop|release\/|rc-main\/|main)$/'
      when: always
    - when: never

sast:
  stage: security
  script:
    - echo "Run SAST scan"
    - ./scripts/run-sast.sh
  artifacts:
    reports:
      sast: gl-sast-report.json
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(develop|release\/|rc-main\/|main)$/'
      when: always
    - when: never

secret_detection:
  stage: security
  script:
    - echo "Run secret detection"
    - ./scripts/run-secret-detection.sh
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(develop|release\/|rc-main\/|main)$/'
      when: always
    - when: never

plan:
  stage: plan
  script:
    - echo "Run deployment plan checks"
    - ./scripts/plan.sh
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(develop|release\/|rc-main\/|main)$/'
      when: always
    - when: never

final_verification:
  stage: verify
  script:
    - echo "Manual final verification before deploy"
  when: manual
  allow_failure: false
  rules:
    - if: '$CI_COMMIT_BRANCH =~ /^(develop|release\/|rc-main\/|main)$/'
      when: manual
    - when: never
```

Reference with validation disabled
----------------------------------

If a repository cannot support validation for a specific module, it can still reference the shared template and suppress only the validation job in the wrapper pipeline:

```yaml
include:
  - project: 'group/gitlab-ci-templates'
    file: '/templates/standard-pipeline.yml'

stages:
  - security
  - deploy

validate:
  rules:
    - when: never
```

Repository Hygiene and Governance
---------------------------------

- Use protected branches and role-based permissions to limit who can merge to production branches.
- Enable required status checks and merge request approvals for protected branches.
- Review pipeline changes in merge requests before they are merged.
- Monitor audit logs and GitLab security dashboards for suspicious activity.

Future Work
-----------

- Implement Azure OpenID Connect for temporary credential retrieval in GitLab CI.
- Define a process for rotating and revoking cloud credentials used by CI.
- Standardize GitLab project templates and CI/CD templates across teams.
- Capture lessons learned and update this living document as practices evolve.
