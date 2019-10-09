function Get-AdsAcl
{
<#
	.SYNOPSIS
		Reads the ACL from an AD object.
	
	.DESCRIPTION
		Reads the ACL from an AD object.
		Allows specifying the server to ask.
	
	.PARAMETER Path
		The DistinguishedName path to the item.
	
	.PARAMETER Server
		The server / domain to connect to.
		
	.PARAMETER Credential
		The credentials to use for AD operations.
	
	.PARAMETER EnableException
		This parameters disables user-friendly warnings and enables the throwing of exceptions.
		This is less user friendly, but allows catching exceptions in calling scripts.
	
	.EXAMPLE
		PS C:\> Get-ADUser -Filter * | Get-AdsAcl
		
		Returns the ACL of every user in the domain.
#>
	[OutputType([System.DirectoryServices.ActiveDirectorySecurity])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Alias('DistinguishedName')]
		[string[]]
		$Path,
		
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
		if (Test-PSFFunctionInterrupt) { return }
		
		foreach ($pathItem in $Path)
		{
			if (-not $pathItem) { continue }
			Write-PSFMessage -String 'Get-AdsAcl.Processing' -StringValues $pathItem
			
			try { $adObject = Get-ADObject @adParameters -Identity $pathItem -Properties ntSecurityDescriptor }
			catch { Stop-PSFFunction -String 'Get-AdsAcl.ObjectError' -StringValues $pathItem -Target $pathItem -EnableException $EnableException -Cmdlet $PSCmdlet -ErrorRecord $_ -Continue }
			$aclObject = $adObject.ntSecurityDescriptor
			Add-Member -InputObject $aclObject -MemberType NoteProperty -Name DistinguishedName -Value $adObject.DistinguishedName -Force
			$aclObject
		}
	}
}