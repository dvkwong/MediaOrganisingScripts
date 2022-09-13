param(
    $DestinationFolder = $PSScriptRoot,
    $SourceFolders = 'D:\ServerFolders\PhotoArchive',
    #(Join-Path $PSScriptRoot '2016'),
    $FolderFormat = "yyyy\\MM MMM",
    $FileNameDateRegex = "(\d{4}-\d{2}-\d{2}|\d{8})",
    [string[]]$OtherDateTimeFormats = @("yyyyMMdd"),
    $CurrentCulture = (Get-Culture),
    $PrefixDateFormat = "yyyy-MM-dd",
    $IncludeTypes = @("*.jpg", "*.jpeg", "*.gif", "*.png", "*.mp4", "*.mov", "*.AAE", "*.avi"),
    $ExcludeTypes = @("._*")
)

function ConvertASCII($data)
{
    $ByteArray = [System.Text.Encoding]::ASCII.GetBytes($data)

    $ascii = [System.Text.Encoding]::ASCII.GetString($ByteArray)

    $replace = $ascii -replace "[^\d/-]",""

    return $replace
}

function ParseDate($dateFull)
{
    if($null -eq $dateFull)
    {
        return $null
    }

    [datetime]$fileDate = New-Object DateTime

    $dateString = ConvertASCII($dateFull.Split(' ')[0])

    if ([DateTime]::TryParse($dateString,
            $CurrentCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$fileDate)) {
        return $fileDate
    }

    # Try to parse the date format from matched text
    if ([DateTime]::TryParseExact($dateString, $OtherDateTimeFormats,
            $CurrentCulture,
            [System.Globalization.DateTimeStyles]::None,
            [ref]$fileDate)) {
        return $fileDate
    }

    return $null
}

function Get-DateTakenFunc {
    param
    (
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName')]
        [String]
        $Path
    )

    begin {
        $shell = New-Object -COMObject Shell.Application
    }

    process {
        $returnvalue = 1 | Select-Object -Property Name, DateTaken, Folder
        $returnvalue.Name = Split-Path $path -Leaf
        $returnvalue.Folder = Split-Path $path
        $shellfolder = $shell.Namespace($returnvalue.Folder)
        $shellfile = $shellfolder.ParseName($returnvalue.Name)
        $returnvalue.DateTaken = $shellfolder.GetDetailsOf($shellfile, 12)

        $returnvalue
    }
}
function Get-Datetaken($filePath)
{
    $fileName = [System.IO.Path]::GetFileName($filePath)
    $result = @{}
    $result.DateTaken = $null
    $result.FileNameMatch = $false

    # Try getting the datetaken from the filename if it matches regex
    if ($fileName -match $FileNameDateRegex)
    {
        $fileDate = ParseDate($Matches[0])

        if ($null -ne $fileDate) {
            $result.DateTaken = $fileDate
            $result.FileNameMatch = $true
            return $result
        }
    }

    $result.DateTaken = ParseDate((Get-DateTakenFunc $filePath).DateTaken)

    if ($null -eq $result.DateTaken)
    {
        $result.DateTaken = (Get-ItemPropertyValue $filePath -Name CreationTime)
    }

    return $result
}

Clear-Host

Get-ChildItem -Recurse -Include $IncludeTypes -Exclude $ExcludeTypes $SourceFolders `
| ForEach-Object {

    $result = Get-Datetaken($_.FullName)

    if ($result.DateTaken -eq $null)
    {
        Write-Host Error getting date for $_.FullName
        return
    }

    $folder = Join-Path $DestinationFolder $result.DateTaken.ToString($FolderFormat)
    if(![System.IO.Directory]::Exists($folder))
    {
        [System.IO.Directory]::CreateDirectory($folder)
        Write-Host Creating directory $folder
    }

    $fileName = [System.IO.Path]::GetFileName($_.FullName)
    $destFileName = (Join-Path $folder $fileName)

    #Only move if not already in folder
    if ([System.IO.Path]::GetDirectoryName($_.FullName) -ne $folder)
    {
        if(!(Test-Path $destFileName))
        {
            Move-Item -Path $_.FullName -Destination $folder -Verbose
        }
        else {
            Write-Host File already exists at destination $destFileName
        }
    }

    #Rename file
    if ($PrefixDateFormat -ne "" -and !$result.FileNameMatch)
    {
        $dtFormat = $result.DateTaken.ToString($PrefixDateFormat)

        $renamedFile = (Join-Path $folder "$dtFormat $fileName")

        if (!(Test-Path $renamedFile))
        {
            Rename-Item $destFileName $renamedFile -Verbose
        }
    }
}

Write-Host Finished moving files