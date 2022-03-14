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
	
	.PARAMETER WinRMFailover
		Whether on execution error it should try again using WinRM.
		Default-Value determined using the configuration setting 'ADSec.WinRM.FailOver'
	
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
		PS C:\> Set-AdsOwner -Path $dn -Identity 'contoso\Domain Admins'
		
		Makes the domain admins owner of the path specified in $dn
#>
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseUsingScopeModifierInNewRunspaces', '')]
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('DistinguishedName')]
		[string[]]
		$Path,
		
		[Parameter(Mandatory = $true)]
		[string]
		$Identity,
		
		[switch]
		$WinRMFailover = (Get-PSFConfigValue -FullName 'ADSec.WinRM.FailOver'),
		
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
			if ($Credential) { $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry(($basePath -f $pathItem), $Credential.UserName, $Credential.GetNetworkCredential().Password) }
			else { $directoryEntry = New-Object System.DirectoryServices.DirectoryEntry(($basePath -f $pathItem)) }
			
			Invoke-PSFProtectedCommand -ActionString 'Set-AdsOwner.UpdatingOwner' -ActionStringValues $idReference -ScriptBlock {
				try {
					$secDescriptor = $directoryEntry.InvokeGet('nTSecurityDescriptor')
					if (-not $secDescriptor) { throw 'Failed to access security information' }
					$secDescriptor.Owner = "$idReference"
					$directoryEntry.InvokeSet('nTSecurityDescriptor', $secDescriptor)
					$directoryEntry.CommitChanges()
				}
				catch {
					if (-not $WinRMFailover) { throw }
					
					#region Fallback to WinRM
					$domainController = Get-ADDomainController @adParameters
					$credParam = $PSBoundParameters | ConvertTo-PSFHashtable -Include Credential
					$ldapPath = "LDAP://localhost/$($pathItem)"
					
					Invoke-Command -ComputerName $domainController.HostName @credParam -ScriptBlock {
						param (
							$Identity,
							
							$LdapPath
						)
						try {
							$directoryEntry = New-Object System.DirectoryServices.DirectoryEntry($LdapPath)
							$secDescriptor = $directoryEntry.InvokeGet('nTSecurityDescriptor')
							if (-not $secDescriptor) { throw 'Failed to access security information' }
							$secDescriptor.Owner = $Identity
							$directoryEntry.InvokeSet('nTSecurityDescriptor', $secDescriptor)
							$directoryEntry.CommitChanges()
						}
						catch { throw }
					} -ArgumentList "$idReference", $ldapPath -ErrorAction Stop
					#endregion Fallback to WinRM
				}
			} -Target $pathItem -EnableException $EnableException.ToBool() -Continue -PSCmdlet $PSCmdlet
		}
	}
}