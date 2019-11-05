# Adds the base cmdlets
Add-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
# Add the following if you want to do things with Update Manager
#Add-PSSnapin VMware.VumAutomation
# This script adds some helper functions and sets the appearance. You can pick and choose parts of this file for a fully custom appearance.
. 'c:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1'

$HostName = '192.168.1.10'
$VIBPath = 'C:\Temp\hp-ams-esxi5.5-bundle-10.0.1-2\metadata-hp-ams-esxi5.5-bundle-10.0.1-2.zip'

Connect-VIServer -Server 192.168.1.10 -User root -Password *******

#Try {
  # get-vmhost -Name $HostName | set-VMHost -State Maintenance -ErrorAction Stop
  ##   Catch {
    #    Write-Error "There was a problem putting host $HostName into Maintenance mode."
    #
#}
    

$timeout = new-timespan -Minutes 15
$StopWatch = [diagnostics.stopwatch]::StartNew()

# ---- Wait until all Running VMs have been migrated to another host
while ( ( get-vm -Location $hostName | where PowerState -eq 'PoweredOn' ).Count -GT 0 ) {
    
    if ( $StopWatch.elapsed -gt $TimeOut ) {
        Write-Warning "Migrating VMs from $HostName is taking longer than expected."
        Break
    }

    Start-Sleep -Seconds 30

}

install-VMHostPatch -localPath $VIBPath -HostUserName Root -HostPassword *******

Restart-VMHost -VMHost $HostName






#Get-VMHost -Name $HostName