param(
    $SourceFolders = 'D:\ServerFolders\Photos\2021\04 Apr',
    $IncludeTypes = @("*.jpg", "*.jpeg", "*.gif", "*.png", "*.mp4", "*.mov", "*.AAE", "*.avi"),
    $ExcludeTypes = @("._*")
)

Clear-Host

Get-ChildItem -Recurse -Include $IncludeTypes -Exclude $ExcludeTypes $SourceFolders `
| ForEach-Object {

    Write-Host $_.FullName
}

Write-Host Finished moving files