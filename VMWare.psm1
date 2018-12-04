Function Get-VMWareVMReconfiguration {

<#
    .Synopsis
        List VM Reconfigurations

    .Description
        audit changes made to a virtual machine

    .Parameter Event
        Event of type VmReconfiguredEvent.  Any other type of event will throw an error

    .Example
        List changes in the month of November for the following vm: Server01

        (Get-VIEvent -Entity Server01) | where { $_.gettype().name -eq 'VmReconfiguredEvent' } | Get-VMWareVMReconfiguration

    .Link
        Modified script from this link

 
        http://www.lucd.info/2009/12/18/events-part-3-auditing-vm-device-changes/

    .Note
        Author : Jeff Buenting
        Date : 2018 DEC 03
        
#>

    [CmdletBinding()]
    Param (
        [parameter( Mandatory = $True, ValueFromPipeline = $True)]
        [VMWare.Vim.VmReconfiguredEvent[]]$Event
    )

    Process {
        Foreach ( $E in $Event ) {
            Write-verbose "Auditing $($E.VM.name)"

            $event.ConfigSpec.DeviceChange | Foreach {
			    if($_.Device -ne $null){
				    $report = New-Object PSObject -Property @{
					    VMname = $E.VM.Name
					    Date = $E.CreatedTime
					    User = $E.UserName
					    Device = $_.Device.GetType().Name
					    Operation = $_.Operation
				    }

                    Write-Output $Report
			    }
		    }
        }
    }
}

