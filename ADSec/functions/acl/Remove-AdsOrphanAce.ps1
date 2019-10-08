function Remove-AdsOrphanAce
{
<#
	.SYNOPSIS
		Removes all access rules that have an unresolveable identity.
	
	.DESCRIPTION
		Removes all access rules that have an unresolveable identity.
		This is aimed at identifying and remediating orphaned SIDs in active directory.
	
	.PARAMETER Path
		The full distinguished name to the object to clean.
	
	.PARAMETER ExcludeDomainSID
		SIDs from the specified domain SIDs will be ignored.
		Use this to safely handle one-way trust where ID resolution is impossible for some IDs.
	
	.PARAMETER IncludeDomainSID
		If specified, only unresolved identities from the specified SIDs will be listed.
		Use this to safely target only rules from your owned domains in the targeted domain.
	
	.PARAMETER Server
		The server / domain to connect to.
		
	.PARAMETER Credential
		The credentials to use for AD operations.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.EXAMPLE
		PS C:\> Get-ADObject -LDAPFillter '(objectCategory=*)' | Remove-AdsOrphanAce
	
		Purges all objects in the current domain from orphaned access rules.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	param (
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[string[]]
		$Path,
		
		[string[]]
		$ExcludeDomainSID,
		
		[string[]]
		$IncludeDomainSID,
		
		[string]
		$Server,
		
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[switch]
		$EnableException
	)
	
	begin
	{
		$adParameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		Assert-ADConnection @adParameters -Cmdlet $PSCmdlet
		
		function Write-Result
		{
			[CmdletBinding()]
			param (
				[string]
				$Path,
				
				[System.DirectoryServices.ActiveDirectoryAccessRule]
				$AccessRule,
				
				[ValidateSet('Deleted', 'Failed')]
				[string]
				$Action,
				
				[System.Management.Automation.ErrorRecord]
				$ErrorRecord
			)
			
			[PSCustomObject]@{
				PSTypeName = 'ADSec.AccessRule'
				Path	   = $Path
				Identity   = $AccessRule.IdentityReference
				Action	   = $Action
				ADRights   = $AccessRule.ActiveDirectoryRights
				Type	   = $AccessRule.AccessControlType
				ObjectType = $AccessRule.ObjectType
				InheritedOpectType = $AccessRule.InheritedObjectType
				Rule	   = $AccessRule
				Error	   = $ErrorRecord
			}
		}
		
		# Wrap as nested pipeline to avoid asserting connection each time
		$scriptCmd = { Get-AdsAcl @adParameters -EnableException:$EnableException }
		$getAdsAcl = $scriptCmd.GetSteppablePipeline()
		$getAdsAcl.Begin($true)
	}
	process
	{
		foreach ($pathItem in $Path)
		{
			Write-PSFMessage -Level Verbose -String 'Remove-AdsOrphanAce.Searching' -StringValues $pathItem
			try { $acl = $getAdsAcl.Process($pathItem) | Write-Output }
			catch { Stop-PSFFunction -String 'Remove-AdsOrphanAce.Read.Failed' -StringValues $pathItem -EnableException $EnableException -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue }
			if (-not $acl) { Stop-PSFFunction -String 'Remove-AdsOrphanAce.Read.Failed' -StringValues $pathItem -EnableException $EnableException -Cmdlet $PSCmdlet -Continue }
			
			$rulesToPurge = foreach ($rule in $acl.Access)
			{
				if ($rule.IsInherited) { continue }
				if ($rule.IdentityReference -is [System.Security.Principal.NTAccount]) { continue }
				if ($rule.IdentityReference.AccountDomainSID.Value -in $ExcludeDomainSID) { continue }
				if ($IncludeDomainSID -and ($rule.IdentityReference.AccountDomainSID.Value -notin $IncludeDomainSID)) { continue }
				
				try { $null = $rule.IdentityReference.Translate([System.Security.Principal.NTAccount]) }
				catch
				{
					$null = $acl.RemoveAccessRule($rule)
					$rule
				}
			}
			if (-not $rulesToPurge)
			{
				Write-PSFMessage -Level Verbose -String 'Remove-AdsOrphanAce.NoOrphans' -StringValues $pathItem
				continue
			}
			
			Invoke-PSFProtectedCommand -ActionString 'Remove-AdsOrphanAce.Removing' -ActionStringValues ($rulesToPurge | Measure-Object).Count -Target $pathItem -ScriptBlock {
				try
				{
					Set-ADObject @adParameters -Identity $pathItem -Replace @{ ntSecurityDescriptor = $acl } -ErrorAction Stop
					foreach ($rule in $rulesToPurge) { Write-Result -Path $pathItem -AccessRule $rule -Action Deleted }
				}
				catch
				{
					foreach ($rule in $rulesToPurge) { Write-Result -Path $pathItem -AccessRule $rule -Action Failed -ErrorRecord $_ }
					throw
				}
			} -EnableException $EnableException.ToBool() -PSCmdlet $PSCmdlet -Continue
		}
	}
	end
	{
		$getAdsAcl.End()
	}
}