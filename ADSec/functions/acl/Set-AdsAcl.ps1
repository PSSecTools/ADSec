function Set-AdsAcl
{
<#
	.SYNOPSIS
		Updates the ACL on an active directory object.
	
	.DESCRIPTION
		Updates the ACL on an active directory object.
		Used to manage AD delegation.
	
	.PARAMETER Path
		The path / distinguishedname to the object to manage.
	
	.PARAMETER AclObject
		The acl to apply
	
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
		PS C:\> $acl | Set-AdsAcl
	
		Applies the acl object(s) stored in $acl.
		Assumes that 'Get-AdsAcl'  was used to retrieve the data originally.
	
	.EXAMPLE
		PS C:\> Set-AdsAcl -AclObject $acl -Path $dn -Server fabrikam.com
	
		Updates the acl on the object stored in $dn within the fabrikam.com domain.
#>
	[CmdletBinding(SupportsShouldProcess = $true)]
	Param (
		[Alias('DistinguishedName')]
		[string]
		$Path,
		
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[System.DirectoryServices.ActiveDirectorySecurity]
		$AclObject,
		
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
	}
	process
	{
		if (-not $Path)
		{
			if ($AclObject.DistinguishedName) { $Path = $AclObject.DistinguishedName }
			else
			{
				Stop-PSFFunction -String 'Set-AdsAcl.NoPath' -Target $AclObject -EnableException $EnableException -Category InvalidArgument
				return
			}
		}
		Invoke-PSFProtectedCommand -ActionString 'Set-AdsAcl.SettingSecurity' -Target $Path -ScriptBlock {
			Set-ADObject @adParameters -Identity $Path -Replace @{ ntSecurityDescriptor = $AclObject } -ErrorAction Stop
		} -EnableException $EnableException.ToBool() -PSCmdlet $PSCmdlet
	}
}