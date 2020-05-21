Write-Verbose "$(Get-ChildItem -path $PSScriptRoot\Functions\*.ps1 -| where Name -notlike '@*' | out-string )"
Get-ChildItem -path $PSScriptRoot\Functions\*.ps1 -| where Name -notlike '@*' | Foreach { 
    Write-Verbose "Dot Sourcing $_.FullName"
    Write-verbose "Hello"
    . $_.FullName 
}
