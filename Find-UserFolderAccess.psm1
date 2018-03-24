class AccessResult
{
    [string]$User
    [string]$Path
    [bool]$Access
    [string]$AccessBy   
}
<#

.SYNOPSIS
Function to find if a specific user has accesss to a specific network share

.DESCRIPTION
This function will return true or false if the user has access, if true will also show by which group the access is given.
You will need the AD module installed for this to work, aslo these modules:
Get-ADGroupParent
Get-UserMemberOfGroup

.EXAMPLE
Find-UserFolderAccess -FolderPath "\\server.it.com\domain\common\folder" -User AdUsername

.NOTES
  Version:        0.5
  Author:         Magnus Cotz
  Creation Date:  2018-03-24
#>
function Find-UserFolderAccess
{
    param
    (
        [parameter(Mandatory=$true)][string]$FolderPath,
        [parameter(Mandatory=$true)][string]$User
    )
    #Check if Active Direcotry module exists and dependencies functions
    $AdModule = Get-Module -ListAvailable -name ActiveDirectory
    
    if ([bool]$AdModule -eq $false)
    {
        Write-Error "ActiveDirectory module not found"
        return
    }

    if (([bool](Get-Command Get-ADGroupParent -errorAction SilentlyContinue)) -eq $false) 
    {
        Write-Error "Get-ADGroupParent Command not found"
        return
    }

    if (([bool](Get-Command Get-UserMemberOfGroup -errorAction SilentlyContinue)) -eq $false) 
    {
        Write-Error "Get-UserMemberOfGroup Command not found"
        return
    }

    #First check to see if user exists in AD, if not exit now
    $UserPing = $null
    $UserPing = Get-ADObject -Filter {(objectclass -eq "user" -and Name -eq $User)}

    if ($UserPing -eq $null)
    {
        Write-Error "Could not find user $User in AD"
        return
    }

    #Return value
    $MyAccessResult = New-Object AccessResult
    $MyAccessResult.Access = $false
    $MyAccessResult.Path = $FolderPath
    $MyAccessResult.User = $User
    $MyAccessResult.AccessBy = "None" 

    #Get groups and users who has access to the folder
    
    $Acl = Get-Acl -Path $FolderPath -ErrorAction SilentlyContinue -ErrorVariable AclError
    if ($AclError.count)
    {
        return $AclError
    }

    $AccessToFolder = New-Object System.Collections.ArrayList

    foreach ($g in $Acl.access.IdentityReference)
    {
        if ($g.GetType().ToString() -eq "System.Security.Principal.NTAccount")
        {
            [string]$CleanName = $g.Value
            $tempArray = $CleanName.Split("\")
            $CleanName = $tempArray[1]
            
            #If user has direct access to folder, return now
            if ($CleanName -eq $User)
            {
                $MyAccessResult.Access = $true
                $MyAccessResult.AccessBy = "Direct Access"
                return $MyAccessResult
            }

            #Othewise store the groups and users who has access to the folder
            $AccessToFolder.add($CleanName) | Out-Null
        }
    }

    $AdGroupsWithAccessToFolder = New-Object System.Collections.ArrayList

    #Trim away the user types from the access list
    foreach ($obj in $AccessToFolder)
    {
        $MyAdObject = Get-ADObject -Filter {(objectclass -eq "group" -and Name -eq $obj)}

        if ($MyAdObject -ne $null -and $AdGroupsWithAccessToFolder.Contains($MyAdObject.Name) -ne $true)
        {
            $AdGroupsWithAccessToFolder.Add($MyAdObject.Name) | Out-Null
        }
    }

    #Get groups that the user is member of
    $UserMemberOfGroups = Get-UserMemberOfGroup -User $User

    #Get the parent groups of the groups the user is member of
    $AccessFound = New-Object System.Collections.ArrayList

    ForEach ($g in $UserMemberOfGroups)
    {
        #If direct group has access to folder, return true
        if ($AdGroupsWithAccessToFolder.Contains($g))
        {
            $MyAccessResult.Access = $true
            $MyAccessResult.AccessBy = $g
            return $MyAccessResult
        }
        
        #Else, get the parent groups and see if they have access
        $CurrentGroupInfo = Get-ADGroupParent -Group $g
        
        foreach($ginfo in $CurrentGroupInfo.ParentTree)
        {
            if ($AdGroupsWithAccessToFolder.Contains($ginfo))
            {
                $MyAccessResult.Access = $true
                $MyAccessResult.AccessBy = $g
                return $MyAccessResult
            }
        }
    }

    return $MyAccessResult
}