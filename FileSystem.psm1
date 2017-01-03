<# this is an attempt at replacing the built-in file resource
    with a class based implementation

    Known Issues
    ------------
        - no support for network shares
        - no support for file attributes
        - no caching
#>
data LocalizedData
{
    # culture="en-US"
    ConvertFrom-StringData @'
SourcePathContents = SourcePath and Contents cannot be specified at the same time.
WildCardNotSupported = Wildcard characters are not supported in %1 property.
DirectoryExists = A directory with the specified name %1 exists.
'@
}

Import-LocalizedData LocalizedData -FileName FileSystem.Strings.psd1

enum SourceCondition
{
        SourceNotSpecified
		SourceIsContent          
		SourceIsProblematic        # Source doesn't contain wild card, but is not accessible now.
		SourceIsSingleFile         
		SourceIsDirectory 
		SourceIsWildCard           # wild card characters are used
		SourceIsNetWorkShareOrRoot  # source is "network share" itself or root directory itself
}

enum DestinationCondition
{
		DestinationNotExists 
		DestinationSingleFile 
		DestinationDirectory 
		DestinationWildCard       # wild card characters are used
}

enum Ensure
{
    Present
    Absent
}

enum FileType
{
    File
    Directory
}

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

#region Hidden Properties
    hidden [SourceCondition] $SourceCondition
    hidden [DestinationCondition] $DestinationCondition
    hidden [Ensure] $EnsureResolved
    hidden [FileType] $FileType 

#endregion Hidden Properties

#region DSC Methods
    [bool] Test()
    {
        $this.ResolveAndValidateProperties()

        if ($this.EnsureResolved -eq [Ensure]::Absent)
        {
            return $this.TestAbsent()
        }

        return $this.TestPresent()
    }

    [void] Set()
    {
        $this.ValidateProperties()
    }

    [File] Get()
    {
        $this.ValidateProperties()
        return $this 
    }
#endregion DSC Methods

#region Helper Methods

    [bool] IsContentsSpecified()
    {
        if ([string]::IsNullOrEmpty($this.Contents))
        {
            return $false
        }        

        return $true
    }

    [bool] IsSourcePathSpecified()
    {
        if ([string]::IsNullOrEmpty($this.IsSourcePathSpecified()))
        {
            return $false
        }        

        return $true
    }

    # this method assumes that ResolveProperties() is called
    # before this is called
    hidden [void] ValidateProperties()
    {
        # SourcePath and Contents cannot be specified together
        if ($this.IsContentsSpecified() -and $this.IsSourcePathSpecified())
        {
            throw $this.NewErrorRecord("MI RESULT 4", [System.Management.Automation.ErrorCategory]::InvalidArgument, $Script:LocalizedData.SourcePathContents)
        }

        # DestinationPath cannot contain wildcards
        if ($this.DestinationCondition -eq [DestinationCondition]::DestinationWildCard)
        {
            throw $this.NewErrorRecord("MI RESULT 4", [System.Management.Automation.ErrorCategory]::InvalidArgument, ($script:LocalizedData.WildcardNotSupported -f "DestinationPath"), $null)
        }

        # if no SourcePath is specified, Type is File and DestinationPath already has a directory, it is an error 
        if ($this.SourceCondition -eq [SourceCondition]::SourceNotSpecified -and $this.FileType -eq [FileType]::File -and $this.DestinationCondition -eq [DestinationCondition]::DestinationDirectory)
        {
            throw $this.NewErrorRecord("MI RESULT 4", [System.Management.Automation.ErrorCategory]::InvalidArgument, ($Script:LocalizedData.DirectoryExists -f $this.DestinationPath), $null)
        }
    }

    hidden [void] ResolveAndValidateProperties()
    {
        $this.ResolveProperties()
        $this.ValidateProperties()
    }

    hidden [System.Management.Automation.ErrorRecord] NewErrorRecord([string] $errorId, [System.Management.Automation.ErrorCategory] $category, [string] $Reason)
    {
        $ex = New-Object System.Exception $Reason
        $e = New-Object System.Management.Automation.ErrorRecord $ex, $errorId, $category, $null 

        return $e 
    }

    [bool] IsDestinationPathPresent()
    {
        return (Test-Path $this.DestinationPath)
    }

    [void] ResolveProperties()
    {
        $this.ResolveDestinationPath()
        $this.ResolveEnsure()
        $this.ResolveFileType()
        $this.ResolveSourcePath()
    }

    [void] ResolveDestinationPath()
    {
        #TODO: Check for remote path
        #TODO: check for drive
        #TODO: check for root directory
        #TODO: check for wildcard in directory
        if ($this.IsPathWildCarded($this.DestinationPath))
        {
            $this.DestinationCondition = [DestinationCondition]::DestinationWildCard
            return
        }

        # check if path exists
        if (-not $this.IsDestinationPathPresent())
        {
            $this.DestinationCondition = [DestinationCondition]::DestinationNotExists
            return
        }

        # check if file or directory
        if ($this.IsPathDirectory())
        {
            $this.DestinationCondition = [DestinationCondition]::DestinationDirectory
        }
        else
        {
            $this.DestinationCondition = [DestinationCondition]::DestinationSingleFile
        }

    }

    [void] ResolveEnsure()
    {
        # when Ensure is not specified it is assumed as "Present"
        if ([string]::IsNullOrEmpty($this.Ensure) -or $this.Ensure -eq 'Present')
        {
            $this.EnsureResolved = [Ensure]::Present
        }
        else
        {
            $this.EnsureResolved = [Ensure]::Absent
        }
    }

    [void] ResolveFileType()
    {
        $this.ResolveSourcePath()

        if ([string]::IsNullOrEmpty($this.Type) -and $this.Recurse -and ($this.SourceCondition -eq [SourceCondition]::SourceIsDirectory))
        {
            # when type is not specified but recurse is specified 
            # against a source directory, then the destination is
            # assumed to be of type directory
            $this.FileType = [FileType]::Directory
            return
        }

        if ($this.Type -eq 'File')
        {
            $this.FileType = [FileType]::File
        }
        else
        {
            $this.FileType = [FileType]::Directory
        }
    }

    [void] ResolveSourcePath()
    {
        if ($this.IsContentsSpecified() -and $this.IsSourcePathSpecified())
        {
            throw $this.NewErrorRecord("MI RESULT 4", [System.Management.Automation.ErrorCategory]::InvalidArgument, $Script:LocalizedData.SourcePathContents)
        }

        if (!$this.IsContentsSpecified() -and !$this.IsSourcePathSpecified())
        {
            $this.SourceCondition = [SourceCondition]::SourceNotSpecified
            return
        }

        if ($this.IsContentsSpecified())
        {
            $this.SourceCondition = [SourceCondition]::SourceIsContent
            return
        }

        if ($this.IsPathWildCarded($this.SourcePath))
        {
            $this.SourceCondition = [SourceCondition]::SourceIsWildCard
            return
        }

        if ($this.IsPathDirectory($this.SourcePath))
        {
            $this.SourceCondition = [SourceCondition]::SourceIsDirectory
            #TODO: add support for source is remote directory
        }
        else
        {
            $this.SourceCondition = [SourceCondition]::SourceIsSingleFile
        }
    }
    
    hidden [bool] IsPathWildCarded([string]$Path)
    {
        return ($this.DestinationPath.Contains('*') -or $this.DestinationPath.Contains('?'))
    }

    hidden [bool] IsPathDirectory([string]$Path)
    {
        return ((Get-Item -LiteralPath $Path) -is [System.IO.DirectoryInfo])
    }

    hidden [bool] TestAbsent()
    {
        if ( ($this.DestinationCondition -eq [DestinationCondition]::DestinationNotExists ) -or ($this.DestinationCondition -eq [DestinationCondition]::DestinationDirectory -and $this.FileType -eq [FileType]::File) -or ($this.DestinationCondition -eq [DestinationCondition]::DestinationSingleFile -and $this.FileType -eq [FileType]::Directory))
        {
            # destination does not exist
            # or destination exists but is of a different type
            # than specified
            return $true
        }

        return !(Test-Path -LiteralPath $this.DestinationPath)
    }

    hidden [bool] TestPresent()
    {
        if ($this.FileType -eq [FileType]::File)
        {
            switch ($this.SourceCondition)
            {
                "SourceNotSpecified" 
                {
                    return $this.TestPresentSourceNotSpecified()
                }

                "SourceIsContents"
                {
                    return $this.TestPresentSourceContents()
                }

                "SourceIsSingleFile"
                {
                    return $this.TestPresentSourceSingleFile()
                }
            
            }
        }
        return $false
    }

    hidden [bool] TestPresentSourceNotSpecified()
    {
        switch ($this.DestinationCondition)
        {
            "DestinationNotExists" {throw "Error condition, shouldn't hit this case"; continue}
            "DestinationSingleFile" 
            {
                return $this.TestSingleFile()
            }
            "DestinationDirectory" 
            {
                if ($this.FileType -eq [FileType]::File) {throw "Error condition, shouldn't hit this case"; continue}

                return $this.IsDestinationPathPresent()
            }
            "DestinationWildCard" {throw "Error condition, shouldn't hit this case"; continue}
        }
        return $false
    }

    hidden [bool] TestSingleFile()
    {
        # TODO: add check for file attributes
        return $this.IsDestinationPathPresent()
    }

    hidden [bool] TestPresentSourceContents()
    {
        switch ($this.DestinationCondition)
        {
            "DestinationNotExists"
            {
                return $this.TestSingleFile()
            }
            "DestinationSingleFile"
            {
                return $this.TestSingleFile()
            }
            "DestinationDirectory"
            {                
                # contents specified, but there is a
                # directory existing at destination path
                # return false to ensure Set method
                # will delete the directory and create the file
                return $false
            }
            "DestinationWildCard" {throw "Error condition, shouldn't hit this case"; continue}
        }
        return $false
    }

    hidden [bool] TestPresentSourceSingleFile()
    {
        switch ($this.DestinationCondition)
        {
            "DestinationNotExists"
            {
                return $false
            }
            "DestinationSingleFile"
            {
                # if destination is a file need to check
                # contents of the file to test
                return $this.TestSingleFileContents()
            }
            "DestinationDirectory"
            {
                # if destination is a directory then
                # file needs to be created there
                # so test return false
                return $false
            }
            "DestinationWildCard"
            {
                throw $this.NewErrorRecord("MI RESULT 4", [System.Management.Automation.ErrorCategory]::InvalidArgument, ($script:LocalizedData.WildcardNotSupported -f "DestinationPath"), $null)
            }
        }
        return $false
    }

    hidden [bool] TestSingleFileContents()
    {
        # creation or modified date being the same does not
        # guarantee that the contents are the same
        # still need to validate contents
        if ([string]::IsNullOrEmpty($this.CheckSum) -or $this.CheckSum -eq 'CreatedDate' -or $this.CheckSum -eq 'ModifiedDate')
        {
            $ChecksumResolved = 'SHA-1'
        }
        else
        {
            $ChecksumResolved = $this.CheckSum
        }

        $SourceHash = Get-FileHash -Path $this.SourcePath -Algorithm $ChecksumResolved 
        $DestHash = Get-FileHash -Path $this.DestinationPath -Algorithm $ChecksumResolved

        return ($SourceHash -eq $DestHash)
    }
#endregion Helper Methods
}