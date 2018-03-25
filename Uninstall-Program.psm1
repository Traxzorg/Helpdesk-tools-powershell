class Program
{
    [string]$DisplayName
    [string]$DisplayVersion
    [string]$UninstallString
    [string]$ComputerName
}

<#

.SYNOPSIS
Function to uninstall MSI installed programs

.DESCRIPTION
You can use Get-InstalledPrograms to pipe to this function, or use the Program parameter.

.EXAMPLE
Get-InstalledPrograms | Where-Object -Property DisplayName -eq "FileZilla" | Uninstall-Program

.NOTES
  Version:        0.5
  Author:         Magnus Cotz
  Creation Date:  2018-03-24

#>

function Uninstall-Program{
    param(
    [parameter()] [string]$computer = "localhost",
    [parameter(mandatory=$false)] [string]$Program = [string]::empty,
    [parameter(mandatory=$false, ValueFromPipeline=$true)] $ProgramFromPipe
    )
    
    if ($Program -ne [string]::Empty)

    {
        #Get selected programs from selected computer
        $actualProgram = get-installedPrograms -ComputerName $computer | Where-Object -Property displayname -like *$Program*

        # If more than one programs is found
        [int]$choice = 0
        if ($actualProgram.count -ge 1)
        {
            write-host "To many programs found like $Program, select one:"

            [int]$index = 0
            foreach ($progg in $actualProgram.DisplayName)
            {
                write-host [$index]$progg
                $index++
            }
            $temp = $index - 1
            write-host "Enter choice: (0 - $temp): " -NoNewline
            while (($choice = read-host) -ge $index) {}

            $actualProgram = $actualProgram[$choice]
        }

        $temp = $actualProgram.DisplayName
        write-verbose "Selected program is: $temp" 

        Uninstall($actualProgram)
    }

    elseif ($ProgramFromPipe -ne $null -and $ProgramFromPipe.UninstallString -ne $null)
    {
        Uninstall($ProgramFromPipe)
    }
    
    else
    {
        Write-Error "I need a program name or pipe from command Get-InstalledPrograms"
    }
}

function Uninstall([Program]$Program)
{
    if ($Program.count > 1)
    {
        Write-Error ("Can only uninstall one program at a time.")
        return
    }

    if ($Program.count -eq 0)
    {
        write-host "No program found" -ForegroundColor Red 
        return
    }

    if ($Program.UninstallString -eq $null)
    {
        return
    }

    if ($Program.UninstallString.EndsWith(".exe")) {Write-Error "Uninstall is a exe file, sorry can't help you here."; return;}

    #Replace the /I with /X
    if($Program.UninstallString.Contains("/X"))
    {
         $trimmedUninstallString = $Program.UninstallString.Replace("/X", "/X ")
    }

        if($Program.UninstallString.Contains("/I"))
    {
        $trimmedUninstallString = $Program.UninstallString.Replace("/I", "/X ")
    }
    Write-Verbose "Trimmed uninstallstring: $trimmedUninstallString"

    # Add the /qb part
    $trimmedUninstallString += " /qb"
    Write-Verbose "Trimmed uninstallstring: $trimmedUninstallString"

    # Remove MsiExec.exe from the argument
    $trimmedUninstallString = $trimmedUninstallString.Replace("MsiExec.exe ", "")
    Write-Verbose "Trimmed uninstallstring: $trimmedUninstallString"

    Invoke-Command -ComputerName $Program.ComputerName -ScriptBlock {Start-Process msiexec -ArgumentList $using:trimmedUninstallString -Wait}
}