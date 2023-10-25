$VMNames = "KCADCPROD03"

if ( -Not $VMNames ) {
    # No VM Selected.  Getting all
    $VMs = Get-VM
}
Else {
    $VMs = Get-VM -Name $VMNames
}

Foreach ( $VM in $VMs ) {
    Mount-Tools -Guest 

}