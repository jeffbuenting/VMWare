# https://seankilleen.com/2013/01/how-to-run-vmware-powercli-powershell-scripts-as-a-scheduled-task-field-notes/

import-module C:\Scripts\VMWare\VMWare.psd1 -force

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCeip $False -Confirm:$False

$creds = Get-VICredentialStoreItem -file  C:\VMwareCreds\VCSATask.cred

Connect-VIServer -Server $creds.host -User $creds.User -Password $creds.Password

Get-Template -Name WIN2019STD_T | Update-VMWareVMTemplate -WaitHours 6

Disconnect-VIServer -Confirm:$False