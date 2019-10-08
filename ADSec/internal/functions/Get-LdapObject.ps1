function Get-LdapObject
{
<#
	.SYNOPSIS
		Use LDAP to search in Active Directory
	
	.DESCRIPTION
		Utilizes LDAP to perform swift and efficient LDAP Queries.
	
	.PARAMETER LdapFilter
		The search filter to use when searching for objects.
		Must be a valid LDAP filter.
	
	.PARAMETER Properties
		The properties to retrieve.
		Keep bandwidth in mind and only request what is needed.
	
	.PARAMETER SearchRoot
		The root path to search in.
		This generally expects either the distinguished name of the Organizational unit or the DNS name of the domain.
		Alternatively, any legal LDAP protocol address can be specified.
	
	.PARAMETER Configuration
		Rather than searching in a specified path, switch to the configuration naming context.
	
	.PARAMETER Raw
		Return the raw AD object without processing it for PowerShell convenience.
	
	.PARAMETER PageSize
		Rather than searching in a specified path, switch to the schema naming context.
	
	.PARAMETER SearchScope
		Whether to search all OUs beneath the target root, only directly beneath it or only the root itself.
	
	.PARAMETER Server
		The server / domain to connect to.
	
	.PARAMETER Credential
		The credentials to use.
	
	.EXAMPLE
		PS C:\> Get-LdapObject -LdapFilter '(PrimaryGroupID=516)'
		
		Searches for all objects with primary group ID 516 (hint: Domain Controllers).
#>
	[CmdletBinding(DefaultParameterSetName = 'SearchRoot')]
	param (
		[Parameter(Mandatory = $true)]
		[string]
		$LdapFilter,
		
		[string[]]
		$Properties = "*",
		
		[Parameter(ParameterSetName = 'SearchRoot')]
		[string]
		$SearchRoot,
		
		[Parameter(ParameterSetName = 'Configuration')]
		[switch]
		$Configuration,
		
		[switch]
		$Raw,
		
		[ValidateRange(1, 1000)]
		[int]
		$PageSize = 1000,
		
		[System.DirectoryServices.SearchScope]
		$SearchScope = 'Subtree',
		
		[string]
		$Server,
		
		[System.Management.Automation.PSCredential]
		$Credential
	)
	
	begin
	{
		$searcher = New-Object system.directoryservices.directorysearcher
		$searcher.PageSize = $PageSize
		$searcher.SearchScope = $SearchScope
		if ($Credential)
		{
			$searcher.SearchRoot.Username = $Credential.UserName
			try { $searcher.SearchRoot.Password = $Credential.GetNetworkCredential().Password }
			catch { Stop-PSFFunction -String 'Get-LdapObject.CredentialError' -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true }
		}
		
		if ($SearchRoot)
		{
			if ($SearchRoot -like "LDAP://*") { $searcher.SearchRoot.Path = $SearchRoot }
			elseif ($SearchRoot -notlike "*=*") { $searcher.SearchRoot.Path = "LDAP://DC={0}" -f ($SearchRoot -split "\." -join ",DC=") }
			else { $searcher.SearchRoot.Path = "LDAP://$($SearchRoot)" }
		}
		
		if ($Configuration)
		{
			$searcher.SearchRoot.Path = "LDAP://CN=Configuration,{0}" -f $searcher.SearchRoot.distinguishedName[0]
		}
		if ($Server -and ($searcher.SearchRoot.Path -notmatch '^LDAP://[\w\.]+/'))
		{
			$searcher.SearchRoot.Path = $searcher.SearchRoot.Path -replace '^LDAP://', "LDAP://$Server/"
		}
		Write-PSFMessage -String Get-LdapObject.SearchRoot -StringValues $SearchScope, $searcher.SearchRoot.Path -Level Debug
		
		$searcher.Filter = $LdapFilter
		
		foreach ($property in $Properties)
		{
			$null = $searcher.PropertiesToLoad.Add($property)
		}
		
		Write-PSFMessage -String Get-LdapObject.Searchfilter -StringValues $LdapFilter -Level Debug
	}
	process
	{
		try
		{
			foreach ($ldapobject in $searcher.FindAll())
			{
				if ($Raw)
				{
					$ldapobject
					continue
				}
				$resultHash = @{ }
				foreach ($key in $ldapobject.Properties.Keys)
				{
					# Write-Output verwandelt Arrays mit nur einem Wert in nicht-Array Objekt
					$resultHash[$key] = $ldapobject.Properties[$key] | Write-Output
				}
				if ($resultHash.ContainsKey("ObjectClass")) { $resultHash["PSTypeName"] = $resultHash["ObjectClass"] }
				[pscustomobject]$resultHash
			}
		}
		catch
		{
			Stop-PSFFunction -String 'Get-LdapObject.SearchError' -ErrorRecord $_ -Cmdlet $PSCmdlet -EnableException $true
		}
	}
}