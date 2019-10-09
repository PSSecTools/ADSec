function Set-AdsOwner
{
<#
	.SYNOPSIS
		Changes the owner of the specified AD object to the target identity.
	
	.DESCRIPTION
		Changes the owner of the specified AD object to the target identity.
	
	.PARAMETER Path
		Path to the object to update
	
	.PARAMETER Identity
		Identity to make the new owner.
	
	.PARAMETER Server
		The server / domain to connect to.
		
	.PARAMETER Credential
		The credentials to use for AD operations.
	
	.PARAMETER Confirm
		If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.
	
	.PARAMETER WhatIf
		If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Set-AdsOwner -Path $dn -Identity 'contoso\Domain Admins'
	
		Makes the domain admins owner of the path specified in $dn
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('DistinguishedName')]
		[string[]]
		$Path,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Identity,
		
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
		
		if ($Identity -as [System.Security.Principal.SecurityIdentifier])
		{
			$idReference = [System.Security.Principal.SecurityIdentifier]$Identity
		}
		else
		{
			$idReference = [System.Security.Principal.NTAccount]$Identity
			try { $null = $idReference.Translate([System.Security.Principal.SecurityIdentifier]) }
			catch
			{
				Stop-PSFFunction -String 'Set-AdsOwner.UnresolvedIdentity' -StringValues $Identity -EnableException $EnableException -ErrorRecord $_ -OverrideExceptionMessage
				return
			}
		}
		
		$basePath = 'LDAP://{0}'
		if ($Server) { $basePath = "LDAP://$Server/{0}" }
	}
	process
	{
		if (Test-PSFFunctionInterrupt) { return }
		
		foreach ($pathItem in $Path)
		{
			$aclObject = Get-AdsAcl @adParameters -Path $pathItem
			if ($aclObject.Owner -eq $idReference)
			{
				Write-PSFMessage -String 'Set-AdsOwner.AlreadyOwned' -StringValues $pathItem, $idReference
				continue
			}
			
			# Switching to LDAP as owner changes don't work using AD Module
			$directoryEntry = New-Object System.DirectoryServices.DirectoryEntry(($basePath -f $pathItem))
			if ($Credential)
			{
				$directoryEntry.Username = $Credential.UserName
				$directoryEntry.Password = $Credential.GetNetworkCredential().Password
			}
			
			Invoke-PSFProtectedCommand -ActionString 'Set-AdsOwner.UpdatingOwner' -ActionStringValues $idReference -ScriptBlock {
				$secDescriptor = $directoryEntry.InvokeGet('nTSecurityDescriptor')
				$secDescriptor.Owner = "$idReference"
				$directoryEntry.InvokeSet('nTSecurityDescriptor', $secDescriptor)
				$directoryEntry.CommitChanges()
			} -Target $pathItem -EnableException $EnableException.ToBool() -Continue -PSCmdlet $PSCmdlet
		}
	}
}