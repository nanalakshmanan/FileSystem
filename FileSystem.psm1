# this is an attempt at replacing the built-in file resource
# with a class based implementation
[DscResource()]
class File
{
#region Properties
    [DscProperty(key)]
    [string]
    $DestinationPath

    [DscProperty()]
    [ValidateSet("Archive", "Hidden", "ReadOnly", "System")]
    [string[]]
    $Attributes

    [DscProperty()]
    [ValidateSet("CreatedDate", "ModifiedDate", "SHA-1", "SHA-256", "SHA-512")]
    [string]
    $CheckSum

    [DscProperty()]
    [string]
    $Contents

    [DscProperty()]
    [PSCredential]
    $Credential

    [DscProperty()]
    [ValidateSet("Present", "Absent")]
    [string]
    $Ensure = "Present"

    [DscProperty()]
    [bool]
    $Force

    [DscProperty()]
    [bool]
    $MatchSource

    [DscProperty()]
    [bool]
    $Recurse

    [DscProperty()]
    [string]
    $SourcePath

    [DscProperty()]
    [ValidateSet("File", "Directory")]
    [string]
    $Type

    [DscProperty(NotConfigurable)]
    [DateTime]
    $CreatedDate

    [DscProperty(NotConfigurable)]
    [DateTime]
    $ModifiedDate

    [DscProperty(NotConfigurable)]
    [uint64]
    $Size

    [DscProperty(NotConfigurable)]
    [string[]]
    $SubItems

#endregion Properties

#region DSC Methods
    [bool] Test()
    {
        return $false
    }

    [void] Set()
    {

    }

    [File] Get()
    {
        return $this 
    }
#endregion DSC Methods
}