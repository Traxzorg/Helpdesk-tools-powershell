<#

.SYNOPSIS
Script to get parents for a AD-group

.DESCRIPTION
This function will return an object with the current parents to the group. You can use -GUI to get a visual tree of hierarchy. 

.EXAMPLE
Get-AdGroupParent -Group myGroup -GUI

.NOTES
You will need the AD module installed for this to work.

#>

function Get-ADGroupParent
{
    [CmdletBinding()]
    param
    (
        [parameter(ValueFromPipeline=$true, Mandatory=$true)] [string]$Group,
        [switch]$GUI = $false
    )

    #Check if Active Direcotry module exists
    $AdModule = Get-Module -ListAvailable -name ActiveDirectory
    
    if ([bool]$AdModule -eq $false)
    {
        Write-Error "ActiveDirectory module not found"
        return
    }    

    Add-Type -AssemblyName PresentationFramework
    if ($GUI)
    {
        

[xml]$xaml = @"
    <Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Parent Tree (falling)" Height="400" Width="525"  WindowStartupLocation="CenterScreen">
    <Grid>
        <TreeView Name="Tree" HorizontalAlignment="Center" Height="300" Margin="1,20,0,0" VerticalAlignment="Top" Width="400"/>
    </Grid>
    </Window>
"@ 

$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$Window=[Windows.Markup.XamlReader]::Load( $reader )

$xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach {

New-Variable  -Name $_.Name -Value $Window.FindName($_.Name) -Force
  }
    }
  
    class Node
    {
        [string]$GroupName
        $Parent
        $ParentTree
        
        Node()
        {
            $this.Parent = New-Object System.Collections.ArrayList
            $this.ParentTree = New-Object System.Collections.Generic.List[string]
        }
    }

    # Crate a root node
    $mainNode = New-Object Node
    $mainNode.GroupName = $Group

    # List to keep track of found nodes
    #$nodeList = New-Object System.Collections.ArrayList
    #$nodeList.Add($mainNode) | Out-Null
    $selectedNode = $mainNode

    # List to clean up the string
    $seperator = New-Object System.Collections.ArrayList 
    $seperator.add(',') | Out-Null
    $seperator.Add('=') | Out-Null

    function CleanString([string]$string)
    {
        $tempArray = $string.Split($seperator) # Split DN = , from the string
        return $tempArray[1]
    }

    #List to keep track of the groups vi har checked
    $CheckedGroups = New-Object System.Collections.ArrayList

    function GetAllMemberOf([string]$theGroup, [Node]$currentNode)
    {
            Write-Verbose "Entering function GetAllMemberOf"
            $currentGroup = get-adgroup -Properties * $theGroup

            # Check so the group we are checking are not already checked, to avoid eternity loops, example: group1 -> group2 -> group1
            if ($CheckedGroups.Contains($currentGroup.cn)) 
            {
                continue
            }
            else
            {
                $CheckedGroups.Add($currentGroup.cn) | Out-Null
            }

            # For every group in the array runt this function
            foreach ($member in $currentGroup.memberof)
            {
                [string]$cleanName = CleanString $member

                $newNode = New-Object Node
                $newNode.GroupName = $cleanName
                #$newNode.UnderGroup = CleanString $currentGroup
                $currentNode.Parent.add($newNode) | Out-Null

                #$nodeList.Add($newNode) | Out-Null
                GetAllMemberOf $member $newNode
            }

    }

    GetAllMemberOf $Group $mainNode


    function DisplayTree([Node]$node, [System.Windows.Controls.TreeViewItem]$GuiNode = $null)
    {
        foreach($n in $node.Parent)
        {
            $mainNode.ParentTree.add($n.GroupName)

            if ($GUI)
            {
                $child = New-Object System.Windows.Controls.TreeViewItem
                $child.Header = $n.GroupName
                $child.IsExpanded = $true
                $GuiNode.AddChild($child)

                DisplayTree $n $child
            }
            else
            {
                DisplayTree $n
            }
        }
    }

    if ($GUI)
    {
        $Root = New-Object System.Windows.Controls.TreeViewItem
        $Root.Header = $Group
        $Root.IsExpanded = $true
        DisplayTree $mainNode $Root
        $Tree.Items.Add($Root)
        $Window.ShowDialog()
    }
    else
    {
        DisplayTree $mainNode
        return $mainNode   
    } 
}