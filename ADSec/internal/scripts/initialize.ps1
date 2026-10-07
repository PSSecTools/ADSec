# ON PS7, AD ACL objects do not initialize correctly until successfully completing a Get-Acl call
$null = Get-Acl -Path $PSScriptRoot -ErrorAction Ignore