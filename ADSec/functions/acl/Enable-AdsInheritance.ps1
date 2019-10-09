function Enable-AdsInheritance
{
<#
	.SYNOPSIS
		Enables inheritance on an Active Directoey object.
	
	.DESCRIPTION
		Enables inheritance on an Active Directoey object.
	
	.PARAMETER Path
		The distinguished name of the object to process.
	
	.PARAMETER RemoveExplicit
		By default, all previous access rules will be preserved.
		Using this parameter, all explicit access rules will instead be removed.
	
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
		PS C:\> Get-ADUser administrator | Enable-AdsInheritance
	
		Enables inheritance on the administrator object.
	
	.EXAMPLE
		PS C:\> Get-ADComputer -LDAPFilter '(primaryGroupID=516)' | Enable-AdsInheritance -RemoveExplicit
	
		Remove all explicit permissions for deletion.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('DistinguishedName')]
		[string[]]
		$Path,
		
		[switch]
		$RemoveExplicit,
		
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
		
		# Wrap as nested pipeline to avoid asserting connection each time
		$getCmd = { Get-AdsAcl @adParameters -EnableException:$EnableException }
		$getAdsAcl = $getCmd.GetSteppablePipeline()
		$getAdsAcl.Begin($true)
		
		$setCmd = { Set-AdsAcl @adParameters -EnableException:$EnableException }
		$setAdsAcl = $setCmd.GetSteppablePipeline()
		$setAdsAcl.Begin($true)
	}
	process
	{
		foreach ($pathItem in $Path)
		{
			Write-PSFMessage -String 'Enable-AdsInheritance.Processing' -StringValues $pathItem -Target $pathItem
			try { $aclObject = ($getAdsAcl.Process($pathItem))[0] }
			catch { Stop-PSFFunction -String 'Enable-AdsInheritance.ReadAcl.Failed' -StringValues $pathItem -ErrorRecord $_ -EnableException $EnableException -Continue -Target $pathItem }
			
			$changedAnything = $false
			if ($aclObject.AreAccessRulesProtected)
			{
				$aclObject.SetAccessRuleProtection($false, $true)
				$changedAnything = $true
			}
			if ($RemoveExplicit -and ($aclObject.Access | Where-Object IsInherited -EQ $false))
			{
				($aclObject.Access) | Where-Object IsInherited -EQ $false | & {
					process
					{
						Write-PSFMessage -Level Debug -String 'Enable-AdsInheritance.AccessRule.Remove' -StringValues $_.IdentityReference, $_.ActiveDirectoryRights, $_.AccessControlType -Target $pathItem
						$null = $aclObject.RemoveAccessRule($_)
					}
				}
				$changedAnything = $true
			}
			
			if (-not $changedAnything)
			{
				Write-PSFMessage -String 'Enable-AdsInheritance.NoChange.Skipping' -StringValues $pathItem -Target $pathItem
				continue
			}
			
			Invoke-PSFProtectedCommand -ActionString 'Enable-AdsInheritance.Updating.Acl' -Target $pathItem -ScriptBlock {
				$setAdsAcl.Process($aclObject)
			} -EnableException $EnableException.ToBool() -PSCmdlet $PSCmdlet -Continue
		}
	}
	end
	{
		$getAdsAcl.End()
		$setAdsAcl.End()
	}
}