$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "FileSystem" {

    Context "Schema matches built-in file resource" {
        
        $builtinres = Get-DscResource -Name File -Module PSDesiredStateConfiguration
        $newres = Get-DscResource -Name File -Module FileSystem

        for($i=0; $i -lt $builtinres.Properties.Count; $i++)
        {
           $name = $builtinres.Properties[$i].Name
           $bproperty = $builtinres.Properties[$i]
           $nproperty = $newres.Properties[$i]

           It "Checking Property $name name" {
                
                $bproperty.Name -eq $nproperty.Name | Should be $true
           } 

           It "Checking Property $name type" {
                
                $bproperty.PropertyType -eq $nproperty.PropertyType | Should be $true
           } 


           It "Checking Property $name IsMandatory" {
                
                $bproperty.IsMandatory -eq $nproperty.IsMandatory | Should be $true
           } 

           if ($builtinres.Properties[$i].Values.Count -gt 0)
           {
               It "Checking Property $name Value" {
                
                    $bproperty.Values.Count -eq $nproperty.Values.Count | Should be $true
               } 
           }
        }
    }
}
