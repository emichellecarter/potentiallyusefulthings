# Coding Standards

Version: 1.0

Last updated: 2026-07-22

Purpose
-------

Define general coding standards for scripts, modules, and infrastructure-as-code in this repository. This is a living document and will be updated over time as tooling, compliance requirements, and best practices evolve.

Scope
-----

- General code quality and readability.
- Language-specific conventions for Terraform and PowerShell.
- Documentation, review, and testing requirements.
- Reference material for repository standards.

Standards
---------

- Treat this document and the referenced standards documents as part of repository governance.
  - This is a living document: update it when new best practices, compliance controls, or tooling requirements emerge.
- Use `docs/Terraform-Standards.md` as the authoritative source for Terraform-specific guidance.
  - Follow Terraform module design, naming, validation, remote state, and security requirements from that document.
- Use `docs/Powershell-Standards.md` as the authoritative source for PowerShell-specific guidance.
  - Follow PowerShell script headers, parameter validation, error handling, logging, and testing guidance from that document.
- Keep code clean and maintainable.
  - Use consistent formatting, naming, and documentation conventions.
  - Avoid hardcoded secrets or credentials in code.
  - Prefer explicit inputs and outputs in modules and scripts.
- Use clear and meaningful names.
  - Choose names that describe intent and avoid abbreviations unless they are widely accepted.
  - Use language-appropriate naming conventions consistently.
- Comment and document intentionally.
  - Document non-obvious behavior, decision rationale, and known limitations.
  - Keep comments concise and accurate; update comments when code changes.
- Manage dependencies carefully.
  - Pin versions where possible and avoid floating dependencies.
  - Review third-party modules and libraries for security, license, and compliance implications.
- Build for maintainability and readability.
  - Break large files into smaller logical units where appropriate.
  - Prefer simple, explicit code over clever or ambiguous constructs.
- Enforce security and privacy by design.
  - Avoid embedding secrets in code or repository metadata.
  - Use secure secret management and follow the security guidance in the referenced standards.
  - Keep sensitive outputs marked as sensitive and avoid exposing them in logs.
- Test code before merging.
  - Include unit or integration tests where appropriate.
  - Use automated validation in CI to catch regressions early.
- Keep documentation aligned with code.
  - Update READMEs, module docs, and comments when behavior changes.
  - Use the same terminology across code and documentation.
- Review and approve changes through the standard process.
  - Require peer review for all changes, especially those affecting security or compliance.
  - Capture review notes and approvals in merge request descriptions.
- Use the repository’s living document approach.
  - Review and update these standards periodically.
  - Track changes clearly in the document header and version metadata.

References
----------

- Terraform standards: `docs/Terraform-Standards.md`
- PowerShell standards: `docs/Powershell-Standards.md`
- Living document guidance: update this file as practices evolve and new guidance is adopted.
