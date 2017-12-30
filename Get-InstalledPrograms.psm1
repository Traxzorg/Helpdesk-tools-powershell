class Program
{
    [string]$DisplayName
    [string]$DisplayVersion
    [string]$UninstallString
    [string]$ComputerName
}

<#
.SYNOPSIS
  Show installed programs on a computer.
.DESCRIPTION
  Function that lists installed programs from local or remote computer. Gathers information from the registry

.PARAMETER ComputerName
    Name of remote computer

.PARAMETER SkipUpdates
    Skips Windows updates results from installed programs

.NOTES
  Version:        1.0
  Author:         Magnus Cotz
  Creation Date:  2017-12-30
  
.EXAMPLE
Get-InstalledPrograms -ComputerName RemoteComputer001 -SkipUpdates
List installed programs on a remote computer.

#>

function Get-InstalledPrograms
{
    [CmdletBinding()]
    param(
    [parameter(ValueFromPipeline=$true, Mandatory=$false)] [string]$ComputerName = "localhost",
    [switch]$SkipUpdates
    )

        if ((Test-Connection $ComputerName -Quiet) -eq $false) { return "Failed to connect to $ComputerName" }
        
        #create an array to store the objects in
        $collectionPrograms = New-Object System.Collections.ArrayList
       
        #Gather the programs from the registry        
        if ($ComputerName -eq 'localhost') 
        {
            $registryResult = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*
            $registryResult += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* 
        }
        
        else 
        {        
            $registryResult = Invoke-Command -ComputerName $ComputerName {Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*} 
            $registryResult += Invoke-Command -ComputerName $ComputerName {Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*} 
        }

        #Sort the results
        $registryResult = $registryResult | Sort-Object -Property DisplayName

        #add the values from the registry to the collection of objects
        foreach ($result in $registryResult)
        {
             #Check so there is a value in displayname to avoid ghosts
             if ($result.DisplayName -eq [string]::Empty -or $result.DisplayName -eq $null) {continue}
                       
             #Skip "Update For" results if SkipUpdates is true
             if ($SkipUpdates) { 
             if ($result.DisplayName -like "*Update for*") { continue } }

             #Ignore all the KB's
             if ($result.PSChildName -match "KB\d") {continue}

             #Create a object
             $program = New-Object Program
             $program.DisplayName = $result.DisplayName
             $program.DisplayVersion = $result.DisplayVersion
             $program.UninstallString = $result.UninstallString
             $program.ComputerName = $ComputerName

             #Add the program to the array
             $collectionPrograms.Add($program) | Out-Null
        }
        
        return $collectionPrograms
}