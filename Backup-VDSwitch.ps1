Connect-ViServer NMCPEH-cpsvr1

$Path = "\\nmcpeh-imd-back\e$\vCenter_Backups\COOP\DistributedSwitches\$((Get-Date -UFormat %d%b%Y).ToUpper())"

if ( -Not ( Test-Path -Path $Path ) ) { New-Item -Path $Path -ItemType Directory }

Get-VDSwitch -Name * |foreach { 
    Export-VDSwitch -VDSwitch $_ -Destination $Path\$($_.Name).zip 

    # ----- Backup VDSPort Group
    $PortGroup = Get-VDPortgroup -VDSwitch $_ 
    foreach ( $PG in $PortGroup ) {
        Export-VDPortGroup -VDPortGroup $PG -Destination $Path\$($PG.Name).zip
    }
} 


