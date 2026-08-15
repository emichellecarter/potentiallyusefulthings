# Security Baseline

> This is a living document and may change as new requirements surface.

## Purpose

Standardize Azure security requirements for Cloud One alignment using NIST, IL4, and IL5 policy checks within Azure.

## Security Reference Frameworks

- NIST SP 800-53 controls and mappings.
- Department of Defense Impact Level 4 (IL4) requirements.
- Department of Defense Impact Level 5 (IL5) requirements.
- Azure Policy and Microsoft Defender for Cloud policy assessments.

## Baseline Requirements

- Implement Azure Policy definitions to enforce required security controls for IL4 and IL5 environments.
- Use built-in and custom Azure Policy initiatives for continuous compliance auditing.
- Enable Microsoft Defender for Cloud on subscriptions where applicable.
- Apply role-based access control (RBAC) with least privilege.
- Use conditional access, multifactor authentication, and privileged identity management for admin access.
- Ensure data encryption at rest and in transit using Azure-managed keys, customer-managed keys, or key vault-backed keys.
- Protect network boundaries with Azure Firewall, NSGs, and explicit route table controls.

## Policy and Compliance Checks

- Audit and enforce required tags and naming standards via Azure Policy.
- Validate storage, SQL, and Key Vault encryption settings.
- Monitor disk encryption, endpoint protection, and OS patch compliance.
- Enforce security baseline configurations for virtual machines and PaaS services.
- Require Defender for Cloud recommendations to be addressed or suppressed with justification.
- Maintain logging and monitoring coverage for control-plane, data-plane, and host-level events.

## IL4 / IL5 Considerations

- IL4 environments should align to moderate-impact protections with shared services controls, boundary protections, and logging.
- IL5 environments require elevated protections, stricter isolation, and enhanced auditing.
- Apply tailored policy sets per impact level, explicitly mapping controls to IL4 or IL5 requirements.
- Use Azure Blueprints or policy initiatives to deploy a consistent control baseline for each impact level.

## Implementation Guidance

- Use Azure Policy assignments at subscription or management group scope.
- Leverage policy effects such as `Audit`, `Deny`, and `Modify` depending on enforcement needs.
- Centralize compliance reporting through Azure Policy compliance dashboard and Microsoft Defender for Cloud.
- Document deviations, compensating controls, and approval rationale for non-compliant resources.

## Review and Change Control

- Review this security baseline regularly and whenever new DoD or Azure security requirements are introduced.
- Update policy definitions and controls based on changes to NIST, IL4, IL5, and Azure security guidance.
- Proposed changes should go through a merge request and architecture/security review.

## References & Policy Links

- **Azure Policy (overview)**: https://learn.microsoft.com/azure/governance/policy/overview — Documentation for Azure Policy concepts, definition structure, and assignment.
- **Azure Policy GitHub (definitions & samples)**: https://github.com/Azure/azure-policy — Official repository containing policy definitions, samples, and contribution guidance.
- **Azure Policy samples**: https://github.com/Azure/azure-policy/tree/master/samples — Collection of reusable policy samples and initiatives.
- **Azure Security Benchmark**: https://learn.microsoft.com/azure/security/benchmark/ — Microsoft's security benchmark mapping to CIS/NIST and recommended controls.
- **Microsoft Defender for Cloud**: https://learn.microsoft.com/azure/defender-for-cloud/overview — Guidance on security posture management and threat protection.
- **Azure Blueprints**: https://learn.microsoft.com/azure/governance/blueprints/overview — Compose and deploy repeatable environments including policies and RBAC.
- **Azure compliance documentation**: https://learn.microsoft.com/azure/compliance/ — Mappings for compliance offerings and framework alignments.
- **DISA STIGs**: https://public.cyber.mil/stigs/ — Security Technical Implementation Guides from DISA.
- **DoD Cloud Computing Security Requirements Guide (SRG)**: https://public.cyber.mil/dccs/cloud-computing-security-requirements-guide/ — DoD SRG for cloud providers and consumers.
- **DoD Risk Management Framework (RMF)**: https://public.cyber.mil/rmf/ — DoD RMF guidance and artifacts.
- **DoD CIO guidance & memos**: https://dodcio.defense.gov/ — Office of the DoD Chief Information Officer resources.

Use these resources to locate built-in policy definitions and to assemble policy initiatives that map controls to NIST, IL4, and IL5 requirements. Start with `Audit` assignments to measure compliance, then consider `Modify` or `Deny` for remediation once impact is understood.
