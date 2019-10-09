# This is where the strings go, that are written by
# Write-PSFMessage, Stop-PSFFunction or the PSFramework validation scriptblocks
@{
	'Assert-ADConnection.Failed'			  = 'Failed to connect to {0} as {1}' # $target, $userName
	'Enable-AdsInheritance.AccessRule.Remove' = 'Flagging accessrule for deletion: {0} --> {1} ({2})' # $_.IdentityReference, $_.ActiveDirectoryRights, $_.AccessControlType
	'Enable-AdsInheritance.NoChange.Skipping' = 'No change needed, skipping {0}' # $pathItem
	'Enable-AdsInheritance.Processing'	      = 'Starting process to enable inheritance on {0}' # $pathItem
	'Enable-AdsInheritance.ReadAcl.Failed'    = 'Failed to access acl on {0}' # $pathItem
	'Enable-AdsInheritance.Updating.Acl'	  = 'Enabling inheritance' # 
	'Get-AdsAcl.ObjectError'				  = 'Error accessing item: {0}' # $pathItem
	'Get-AdsAcl.Processing'				      = 'Retrieving Acl from {0}' # $pathItem
	'Get-AdsOrphanAce.Read.Failed'		      = 'Failed to access {0}' # $pathItem
	'Get-LdapObject.CredentialError'		  = 'Invalid username/password' # 
	'Get-LdapObject.SearchError'			  = 'Failed to execute ldap request.' # 
	'Get-LdapObject.Searchfilter'			  = 'Searching with filter: {0}' # $LdapFilter
	'Get-LdapObject.SearchRoot'			      = 'Searching {0} in {1}' # $SearchScope, $searcher.SearchRoot.Path
	'Remove-AdsOrphanAce.NoOrphans'		      = 'No orphaned Ace found on {0}' # $pathItem
	'Remove-AdsOrphanAce.Read.Failed'		  = 'Failed to access {0}' # $pathItem
	'Remove-AdsOrphanAce.Removing'		      = 'Removing {0} Access rule' # ($rulesToPurge | Measure-Object).Count
	'Remove-AdsOrphanAce.Searching'		      = 'Searching {0} for orphaned access rules' # $pathItem
	'Set-AdsAcl.NoPath'					      = 'Failed to update Acl - no path specified and none on input object' # 
	'Set-AdsAcl.SettingSecurity'			  = 'Updating security settings' # 
	'Set-AdsOwner.AlreadyOwned'			      = '{0} is already owned by {1}' # $pathItem, $idReference
	'Set-AdsOwner.UnresolvedIdentity'		  = 'Failed to resolve Identity: {0}' # $Identity
	'Set-AdsOwner.UpdatingOwner'			  = 'Updating owner to {0}' # $idReference
}