<#

.SYNOPSIS
Function to find what ad-groups a ad-user is member of.

.DESCRIPTION
This function will return the groups a user is member of.

.EXAMPLE
Get-UserMemberOfGroup -User myAdUser

.NOTES
  Version:        0.5
  Author:         Magnus Cotz
  Creation Date:  2018-03-24

#>

Function Get-UserMemberOfGroup
{
    param
    (
        [parameter(Mandatory=$true)][string]$User
    )

    #Check if Active Direcotry module exists
    $AdModule = Get-Module -ListAvailable -name ActiveDirectory
    
    if ([bool]$AdModule -eq $false)
    {
        Write-Error "ActiveDirectory module not found"
        return
    }

    $Groups = New-Object System.Collections.ArrayList

    if($GroupSearch = Get-ADPrincipalGroupMembership $User | Select-Object name | Sort-Object -Property "Name")
	{
		foreach ($g in $GroupSearch)
		{
            $Groups.Add($g.name) | Out-Null
		}
        return $Groups
    }

}