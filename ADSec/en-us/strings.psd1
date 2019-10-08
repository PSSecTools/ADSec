# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Assert-ADConnection.Failed'	  = 'Failed to connect to {0} as {1}' # $target, $userName
	'Get-AdsAcl.ObjectError'		  = 'Error accessing item: {0}' # $pathItem
	'Get-LdapObject.CredentialError'  = 'Invalid username/password' # 
	'Get-LdapObject.SearchError'	  = 'Failed to execute ldap request.' # 
	'Get-LdapObject.Searchfilter'	  = 'Searching with filter: {0}' # $LdapFilter
	'Get-LdapObject.SearchRoot'	      = 'Searching {0} in {1}' # $SearchScope, $searcher.SearchRoot.Path
	'Set-AdsAcl.SettingSecurity'	  = 'Updating security settings' # 
	'Set-AdsOwner.AlreadyOwned'	      = '{0} is already owned by {1}' # $pathItem, $idReference
	'Set-AdsOwner.UnresolvedIdentity' = 'Failed to resolve Identity: {0}' # $Identity
	'Set-AdsOwner.UpdatingOwner'	  = 'Updating owner to {0}' # $idReference
}