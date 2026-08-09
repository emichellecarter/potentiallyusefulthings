# PowerShell Standards

Version: 1.0

Last updated: 2026-07-21

Purpose
-------

This document defines PowerShell coding standards and best practices for scripts and modules used by the engineering organization. The goal is consistent, maintainable, secure, and testable PowerShell code across repositories and automation pipelines.

This is a living document and will be updated over time as new requirements and best practices are established.

Scope
-----

Applies to all PowerShell scripts, functions, and modules authored for automation, deployment, configuration, and administrative tooling. This includes scripts committed to repositories, modules published internally, and code executed in CI/CD pipelines.

Conventions Overview
--------------------

- Use PowerShell Core (pwsh) when cross-platform compatibility is required. Use Windows PowerShell only if constrained by platform or legacy dependencies.
- Target explicit PowerShell edition in module manifests or CI jobs.
- Prefer modules over large monolithic scripts for reusable logic.

File and Module Layout
----------------------

- Module directory layout:

	- `ModuleName/`
		- `ModuleName.psm1` — module implementation (minimal; prefer functions in separate `.ps1` files and dot-source or use `Export-ModuleMember`).
		- `ModuleName.psd1` — module manifest.
		- `Public/` and `Private/` (optional) — organization by visibility.
		- `Tests/` — Pester tests.
		- `README.md` — usage and examples.

- Script files should use `.ps1`; modules should use `.psm1` and a `.psd1` manifest.

Example module manifest (`ModuleName.psd1`)
------------------------------------------

```powershell
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = '1.0.0.0'
    GUID = '11111111-2222-3333-4444-555555555555'
    Author = 'Engineering Team'
    CompanyName = 'Contoso'
    Description = 'Reusable automation functions.'
    PowerShellVersion = '7.2'
    CompatiblePSEditions = @('Core', 'Desktop')
    FunctionsToExport = @(
        'Get-ContosoResource'
        'Set-ContosoResource'
    )
}
```

Include a manifest for every module so the module metadata, dependencies, and exported members are explicit and discoverable.

Naming Conventions
------------------

- Use approved `Verb-Noun` for functions and cmdlets (e.g., `Get-`, `Set-`, `New-`, `Remove-`, `Update-`, `Test-`). Prefer built-in approved verbs: see `Get-Verb`.
- Function and script names should be PascalCase. Example: `Get-UserAccount`.
- Parameter names should be PascalCase, such as `ComputerName` or `RetryCount`.
- Keep private helper names simple, for example `_Get-InternalValue`.

Formatting & Style
------------------

- Use 4 spaces for indentation.
- Keep lines at or below 120 characters when practical.
- Use `#` for single-line comments and `<# ... #>` for block comments.
- Prefer single quotes for literal strings and double quotes only when interpolation is required.
- Avoid aliases. Use full cmdlet names such as `Get-ChildItem`, `Set-Content`, `Remove-Item`, `Copy-Item`, and `Write-Output`.

Functions and Script Structure
------------------------------

- Each function should do one thing and be easy to test.
- Use comment-based help for public functions.
- Return objects, not formatted strings, when possible.

Example function template
-------------------------

```powershell
<#
.SYNOPSIS
Short description.

.DESCRIPTION
Longer description.

.PARAMETER Name
The name of the target resource.

.PARAMETER Timeout
Timeout in seconds.

.EXAMPLE
Invoke-SampleOperation -Name 'Alice'
#>
function Invoke-SampleOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateRange(1, 600)]
        [int]$Timeout = 30
    )

    try {
        Write-Verbose "Starting operation for $Name"
        [pscustomobject]@{ Name = $Name; Result = 'OK' }
    }
    catch {
        Write-Error $_
        throw
    }
}
```

Parameters and Validation
-------------------------

- Use `[Parameter(Mandatory = $true)]` for required parameters.
- Use validation attributes such as `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, `[ValidateRange()]`, and `[ValidatePattern()]`.
- Keep validation in the parameter block simple.
- Document requiredness in the `.PARAMETER` help text.

Error Handling
--------------

- Use `try { } catch { }` for operations that may fail.
- Use `-ErrorAction Stop` so errors are caught by `catch`.
- Do not hide errors; log and rethrow when appropriate.

Example:

```powershell
try {
    $content = Get-Content -Path 'C:\config\appsettings.json' -ErrorAction Stop
}
catch {
    Write-Warning "Failed to read config: $($_.Exception.Message)"
    throw
}
finally {
    Write-Verbose 'Completed configuration read attempt.'
}
```

Logging and Output
------------------

- Use standard streams correctly:
  - `Write-Output` for pipeline output (objects).
  - `Write-Verbose` for verbose diagnostic messages.
  - `Write-Information` for informational messages where appropriate.
  - `Write-Warning` for recoverable issues.
  - `Write-Error` for non-recoverable errors.
  - Avoid `Write-Host` except for interactive-only scripts where colored terminal output is required; prefer `Write-Information` or `Write-Verbose`.
- Support common switches: `-Verbose`, `-Debug`, and `-WhatIf`/`Confirm` for cmdlets that modify state where possible or it makes sense.

Logging Helper Function
-----------------------

Provide a small, reusable logging helper that writes consistent log entries to streams and optionally to a file. Use this in scripts to centralize formatting and behavior.

```powershell
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [string]$Component = 'Script',
        [string]$LogDirectory
    )

    $timestamp = (Get-Date).ToString('o')
    $entry = "{0} [{1}] {2}: {3}" -f $timestamp, $Level, $Component, $Message

    if ($LogDirectory) {
        try {
            if (-not (Test-Path -Path $LogDirectory)) {
                New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
            }
            $logFile = Join-Path -Path $LogDirectory -ChildPath "$Component.log"
            $entry | Out-File -FilePath $logFile -Append -Encoding utf8 -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to write log: $($_.Exception.Message)"
        }
    }

    switch ($Level) {
        'DEBUG' { Write-Verbose $Message }
        'INFO'  { Write-Information $Message -InformationAction Continue }
        'WARN'  { Write-Warning $Message }
        'ERROR' { Write-Error $Message }
    }

    return $entry
}

function Open-LogFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    Get-Content -Path $FilePath -ErrorAction Stop
}
```

Example usage

```powershell
$logDir = Join-Path -Path $PSScriptRoot -ChildPath 'logs'
Write-Log -Level INFO -Message 'Starting operation' -Component 'MyScript' -LogDirectory $logDir

try {
    $result = Get-ChildItem -Path $PSScriptRoot -ErrorAction Stop
    Write-Log -Level DEBUG -Message "Found $($result.Count) items" -Component 'MyScript' -LogDirectory $logDir
}
catch {
    Write-Log -Level ERROR -Message $_.Exception.Message -Component 'MyScript' -LogDirectory $logDir
    throw
}
```

Guidance:

- Use `Write-Log` for consistent formatting and file-backed logging when scripts run in automation.
- Keep the log file optional; in ephemeral contexts you may omit `-LogFile` and rely on streams only.
- Ensure the logging helper itself uses `-ErrorAction Stop` when writing files so failures are surfaced and handled.


Security Best Practices
----------------------

- Never store secrets or credentials in source control or plain text files.
- Use `Get-Credential` for ad-hoc credential prompts and `Microsoft.PowerShell.SecretManagement` + `SecretStore` or cloud key vaults (Azure Key Vault) for automation.
- Avoid `ConvertTo-SecureString`/`ConvertFrom-SecureString` unless you fully control and secure the encryption key.
- Use least privilege: avoid running scripts as admin unless required.
- Validate all external inputs and handle untrusted data carefully.

Dependency Management
---------------------

- Declare module dependencies in the `.psd1` manifest using `RequiredModules` and `RequiredAssemblies`.
- Pin versions where stability is required.

Testing and CI
--------------

- Write unit and integration tests using Pester (https://pester.dev). Place tests in a `Tests/` folder with naming convention `*.Tests.ps1`.
- A simple Pester test example:

```powershell
describe 'Get-ItemCount' {
    it 'returns the expected number of items' {
        $items = @('a', 'b', 'c')
        $result = $items.Count
        $result | should -Be 3
    }
}
```

- CI pipeline should run:
	- `pwsh -Command Install-Module -Name Pester -Force` (or use container with Pester installed)
	- Run PSScriptAnalyzer
	- Run Pester tests
	- Fail the build on PSScriptAnalyzer failures or failing tests (configurable tolerances may be allowed for warnings).

Linting and Static Analysis
---------------------------

- Use `PSScriptAnalyzer` with a repository-level ruleset (`.psd1`) to enforce rules. Recommended rulesets include style, security, and maintainability.
- Example CI lint command:

```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

Formatting tools
----------------

- Consider `Invoke-Formatter` (PowerShell) or editor plugins (VS Code PowerShell extension) to keep consistent formatting.

Documentation and Comment-Based Help
-----------------------------------

- Add comment-based help to all exported functions and scripts (use `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.INPUTS`, `.OUTPUTS`, `.NOTES`).
- Maintain a `README.md` for modules with examples and prerequisites.

Required Script Header
----------------------

All scripts must begin with a comment-based help header documenting purpose, parameters, examples, and notes. Place this header at the very top of the script file (before any code or `param()` blocks).

Template (copy & adapt for each script):

```powershell
<#
.SYNOPSIS
	Short summary of what the script does.

.DESCRIPTION
	Longer description of the script, important behavior, and side effects.

.PARAMETER SpNames
	Description for `SpNames` (example param). Replace with your parameter names and descriptions.

.PARAMETER KeyVaultName
	Description for `KeyVaultName`.

.PARAMETER DaysUntilExpiration
	Description for `DaysUntilExpiration`.

.EXAMPLE
	$params = @{
		SpNames = ('servicePrinName1', 'servicePrinName2')
		KeyVaultName = 'MyKeyvault'
		DaysUntilExpiration  = 365
	}

.NOTES
	Author: <Your Name or Team>
	Date: <YYYY-MM-DD>
	Change-Id / Ticket: <optional reference>
#>
```

Example (provided by the team):

```powershell
<#
.SYNOPSIS 
	Creates an array of new application registrations, adds a named password, and adds the password and secret id to a keyvault.  Also will create a new secret for an existing 
	application registration and updates the secret and secret id in the key vault specified.

.DESCRIPTION
	Creates an array of new application registrations, adds a named password, and adds the password and secret id to a keyvault.  Also will create a new secret for an existing 
	application registration and updates the secret and secret id in the key vault specified. TODO: Add content type to secrets in keyvault.

.PARAMETER SpNames
	An array of names for the new application registrations to be created.

.PARAMETER KeyVaultName
	The name of the keyvault to add the secrets to.

.PARAMETER DaysUntilExpiration
	The number of days until the password and secret id expire.

.EXAMPLE
	$params = @{
		SpNames = ('servicePrinName1', 'servicePrinName2')
		KeyVaultName = 'MyKeyvault'
		DaysUntilExpiration  = 365
	}
#>
```

Guidance:

- Keep `.SYNOPSIS` to one or two lines.
- Use `.DESCRIPTION` to explain side effects, prerequisites, and required permissions.
- Document every publicly accepted parameter with `.PARAMETER` and its expected type/format.
- Provide at least one `.EXAMPLE` showing typical usage.
- Include `.NOTES` with author, date, and an optional change ticket reference.


Versioning and Release
----------------------

- Use semantic versioning for modules and tag releases in the repository.
- Update the `.psd1` `ModuleVersion` on release.

Packaging and Distribution
-------------------------

- Package modules with a manifest and include only necessary files in the published package. Use test automation to validate package contents.

Examples and Recipes
--------------------

- Example: using secret management

```powershell
# Retrieve a secret from SecretManagement
$creds = Get-Secret -Name 'service-account'
Invoke-MyAction -Credential $creds
```

- Example: Pester test snippet

```powershell
Describe 'Invoke-SampleOperation' {
	It 'returns expected object' {
		$result = Invoke-SampleOperation -Name 'Test' -RetryCount 1
		$result | Should -BeOfType 'System.Management.Automation.PSCustomObject'
		$result.Name | Should -Be 'Test'
	}
}
```

Recommended Tools and References
--------------------------------

- PowerShell Editor Services / VS Code PowerShell extension
- PSScriptAnalyzer (static analysis)
- Pester (testing)
- Microsoft.PowerShell.SecretManagement and SecretStore
- `Get-Verb` (list approved verbs)

Appendix: Quick Checklist
-------------------------

- [ ] Use `Verb-Noun` names and approved verbs.
- [ ] Add comment-based help to exported functions.
- [ ] Support `-Verbose` and `-WhatIf` where appropriate.
- [ ] Run PSScriptAnalyzer and Pester in CI.
- [ ] Do not store secrets in source control.
- [ ] Return objects, not formatted strings.

Contact and Maintenance
-----------------------

For questions about these standards or to propose changes, open an issue or merge request in the engineering handbook repository.

