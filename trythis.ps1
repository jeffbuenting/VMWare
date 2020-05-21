$PSScriptRoot

Get-ChildItem -path "$PSScriptRoot\Functions\*.ps1" | where Name -notlike '@*' 
Get-ChildItem -path $PSScriptRoot\Functions\*.ps1 -| where Name -notlike '@*' | Foreach { 
    Write-Verbose "Dot Sourcing $_.FullName"
    Write-verbose "Hello"
    . $_.FullName 
}
