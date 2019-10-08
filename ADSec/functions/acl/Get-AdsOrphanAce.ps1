function Get-AdsOrphanAce
{
<#
	.SYNOPSIS
		Returns list of all access rules that have an unresolveable identity.
	
	.DESCRIPTION
		Returns list of all access rules that have an unresolveable identity.
		This is aimed at identifying and help remediating orphaned SIDs in active directory.
	
	.PARAMETER Path
		The full distinguished name to the object to scan.
	
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
	
	.EXAMPLE
		PS C:\> Get-ADObject -LDAPFillter '(objectCategory=*)' | Get-AdsOrphanAce
	
		Scans all objects in the current domain for orphaned access rules.
#>
	[CmdletBinding()]
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
				$AccessRule
			)
			
			[PSCustomObject]@{
				PSTypeName = 'ADSec.AccessRule'
				Path	   = $Path
				Identity   = $AccessRule.IdentityReference
				ADRights   = $AccessRule.ActiveDirectoryRights
				Type	   = $AccessRule.AccessControlType
				ObjectType = $AccessRule.ObjectType
				InheritedOpectType = $AccessRule.InheritedObjectType
				Rule	   = $AccessRule
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
			try { $acl = $getAdsAcl.Process($pathItem) }
			catch { Stop-PSFFunction -String 'Get-AdsOrphanAce.Read.Failed' -StringValues $pathItem -EnableException $EnableException -ErrorRecord $_ -Cmdlet $PSCmdlet -Continue }
			if (-not $acl) { Stop-PSFFunction -String 'Get-AdsOrphanAce.Read.Failed' -StringValues $pathItem -EnableException $EnableException -Cmdlet $PSCmdlet -Continue }
			
			foreach ($rule in $acl.Access)
			{
				if ($rule.IsInherited) { continue }
				if ($rule.IdentityReference -is [System.Security.Principal.NTAccount]) { continue }
				if ($rule.IdentityReference.AccountDomainSID.Value -in $ExcludeDomainSID) { continue }
				if ($IncludeDomainSID -and ($rule.IdentityReference.AccountDomainSID.Value -notin $IncludeDomainSID)) { continue }
				
				try { $null = $rule.IdentityReference.Translate([System.Security.Principal.NTAccount]) }
				catch { Write-Result -Path $pathItem -AccessRule $rule }
			}
		}
	}
	end
	{
		$getAdsAcl.End()
	}
}