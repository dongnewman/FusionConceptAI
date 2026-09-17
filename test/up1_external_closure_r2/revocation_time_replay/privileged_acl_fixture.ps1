param(
  [Parameter(Mandatory = $true)]
  [string] $Path
)

# PRECONDITION: caller already has SeRestorePrivilege.  This script never elevates.
$ErrorActionPreference = 'Stop'
$acl = Get-Acl -LiteralPath $Path
$acl.SetAccessRuleProtection($true, $false)
$acl.SetOwner([System.Security.Principal.NTAccount]::new('NT AUTHORITY', 'NETWORK SERVICE'))
Set-Acl -LiteralPath $Path -AclObject $acl
Get-Acl -LiteralPath $Path | Select-Object Owner, Sddl | ConvertTo-Json -Compress
