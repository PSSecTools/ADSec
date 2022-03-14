function Disable-AdsInheritance {
	<#
	.SYNOPSIS
		Disables inheritance on an Active Directoey object.
	
	.DESCRIPTION
		Disables inheritance on an Active Directoey object.
	
	.PARAMETER Path
		The distinguished name of the object to process.
	
	.PARAMETER DiscardInherited
		By default, all previously inherited access rules will be preserved as new explicit rules.
		Using this parameter, all inherited access rules will be discarded instead.
	
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
		PS C:\> Get-ADUser administrator | Disable-AdsInheritance
	
		Disables inheritance on the administrator object.
	
	.EXAMPLE
		PS C:\> Get-ADComputer -LDAPFilter '(primaryGroupID=516)' | Disable-AdsInheritance -DiscardInherited
	
		Disables inheritance on all domain controllers, remove all previously inherited access rules.
#>
	[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('DistinguishedName')]
		[string[]]
		$Path,
		
		[switch]
		$DiscardInherited,
		
		[string]
		$Server,
		
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[switch]
		$EnableException
	)
	
	begin {
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
	process {
		foreach ($pathItem in $Path) {
			Write-PSFMessage -String 'Disable-AdsInheritance.Processing' -StringValues $pathItem -Target $pathItem
			try { $aclObject = ($getAdsAcl.Process($pathItem))[0] }
			catch { Stop-PSFFunction -String 'Disable-AdsInheritance.ReadAcl.Failed' -StringValues $pathItem -ErrorRecord $_ -EnableException $EnableException -Continue -Target $pathItem }
			
			$changedAnything = $false
			if (-not $aclObject.AreAccessRulesProtected) {
				$aclObject.SetAccessRuleProtection($true, (-not $DiscardInherited))
				$changedAnything = $true
			}
			
			if (-not $changedAnything) {
				Write-PSFMessage -String 'Disable-AdsInheritance.NoChange.Skipping' -StringValues $pathItem -Target $pathItem
				continue
			}
			
			Invoke-PSFProtectedCommand -ActionString 'Disable-AdsInheritance.Updating.Acl' -Target $pathItem -ScriptBlock {
				$setAdsAcl.Process($aclObject)
			} -EnableException $EnableException.ToBool() -PSCmdlet $PSCmdlet -Continue
		}
	}
	end {
		$getAdsAcl.End()
		$setAdsAcl.End()
	}
}