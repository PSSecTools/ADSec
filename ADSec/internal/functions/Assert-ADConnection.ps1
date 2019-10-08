function Assert-ADConnection
{
<#
	.SYNOPSIS
		Ensures basic ad connectivity
	
	.DESCRIPTION
		Ensures basic ad connectivity
		Used to ensure subsequent commands have a chance to succeed with the specified server/credential combination.
	
	.PARAMETER Server
		The server / domain to connect to.
		
	.PARAMETER Credential
		The credentials to use for AD operations.
	
	.PARAMETER Cmdlet
		$PSCmdlet of the calling command. Used to handle errors.
	
	.EXAMPLE
		PS C:\> Assert-ADConnection @adParameters -Cmdlet $PSCmdlet
	
		Asserts that AD operations under the specified circumstances are possible.
#>
	[CmdletBinding()]
	Param (
		[string]
		$Server,
		
		[System.Management.Automation.PSCredential]
		$Credential,
		
		[System.Management.Automation.PSCmdlet]
		$Cmdlet
	)
	
	process
	{
		$adParameters = $PSBoundParameters | ConvertTo-PSFHashtable -Include Server, Credential
		try { $null = Get-ADDomain @adParameters -ErrorAction Stop }
		catch
		{
			if ($Credential) { $userName = $Credential.UserName }
			else { $userName = '{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME }
			if ($Server) { $target = $Server }
			else { $target = $env:USERDNSDOMAIN }
			
			Stop-PSFFunction -String 'Assert-ADConnection.Failed' -StringValues $target, $userName -EnableException $true -Cmdlet $Cmdlet -FunctionName $Cmdlet.CommandRuntime.ToString() -ErrorRecord $_
		}
	}
}