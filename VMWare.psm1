#--------------------------------------------------------------------------------------
# Module for VMWare enhancement functions
#--------------------------------------------------------------------------------------

# -------------------------------------------------------------------------------------
# ----- Dot source the functions in the Functions folder of this module
# ----- Ignore any file that begins with @, this is a place holder of work in progress.

Get-ChildItem -path $PSScriptRoot\Functions\*.ps1 -| where Name -notlike '@*' | Foreach { 
    Write-Verbose "Dot Sourcing $_.FullName"

    . $_.FullName 
}


# -------------------------------------------------------------------------------------
# Alarm Functions
# -------------------------------------------------------------------------------------

Function Get-VMWareAlarm {

<#
    .SYNOPSIS
        Retrieves alarms assigned to VMWare objects.

    .DESCRIPTION
        VMWare objects like datastores, clusters, VMs can all have alarms associated with them.  Get-VMWareAlarm will retrieve the alarm with the specified object.

    .PARAMETER VMWareObject
        Vmware object that can have alarms assign.  Specify this to return the alarms assigned. 

        valid are objects of type Datastore, Folder,Datacenter

    .PARAMETER Name
        Name of the alarm to retrieve.

    .PARAMETER ID
        Alarm ID

    .EXAMPLE
        Retrieve the datacenter alarm with ID alarm-301

        Get-VMWareAlarm -Level Datacenters -ID 'alarm-301'

    .EXAMPLE
        Retrieve all from the Datacenters Parent (root)

        Get-vmwarealarm -vmwareobject (get-folder datacenters)

    .Note
        Author : Jeff Buenting
        Date : 2018 DEC 21
        
#>

    [CmdletBinding(DefaultParameterSetName='default')]
    param (
        [Parameter( Mandatory = $True,ValuefromPipeline = $true )]
        [PSObject[]]$VMWareObject,

        [Parameter(ParameterSetName='Name')]
        [string]$Name,
 
        [Parameter(ParameterSetName='ID')]
        [string]$ID
        
        # ----- What about an inherited switch to get all alarms for object plus any that are inherited from the objects parents on up to root.?  
    )


    Begin {
        $alarmmgr = get-view -ID AlarmManager
    }

    Process {
        foreach ( $VObj in $VMWareObject ) {

            write-verbose "object type = $($VObj.GetType().fullname)"

            # ----- Check if object is valid to have an alarm assigned to it.
            Switch ( $VObj.GetType().fullname ) {
                # ----- vCenter Root
                # ----- The only way I can figure how to get the alarms from the root is to use the get-folder datacenters cmd.
                'VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl' {
                    write-Verbose "Datastores folder (root)"
                }
            
                # ----- Datastore
                'VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl' { 
                    write-verbose "datastore" 
                }

                # ----- Datacenter
                'VMware.VimAutomation.ViCore.Impl.V1.Inventory.DatacenterImpl' {
                    write-Verbose 'datacenters'
                }

                default {
                    Throw "Error : Object cannot have an alarm assigned to it."
                }
            }

            Try {
                ## ----- Converts level to a folder view.
                #$From = Get-Folder -Name $Level -ErrorAction Stop | get-view -ErrorAction Stop

                # ----- Take object and convert to view so we can get the MoRef
                $V = $VObj | Get-View

                Write-Debug "$($V | out-string)"
            }
            catch {
                $ExceptionMessage = $_.Exception.Message
                $ExceptionType = $_.Exception.GetType().Fullname
                Throw "Get-VMWareAlarm : Error getting VIObject Folder Level.`n`n     $ExceptionMessage`n`n $ExceptionType"
            }

            Write-Verbose "Set Name = $($PSCmdlet.ParameterSetName)"

            # ----- Return alarms for specified object.  Either all or filtered.
            Switch ( $PSCmdlet.ParameterSetName ) {
                'ID' {
                    Write-verbose "Search for ID : $ID"
                    $alarmmgr.getalarm( $V.MoRef ) | where Value -like $ID | foreach { Write-output (Get-View $_).info }
                }   
            
                'Name' {
                    Write-verbose "Search for Name : $Name"
                    $alarmmgr.getalarm( $V.MoRef ) | foreach { Write-output ((Get-View $_).info | where name -like $Name ) }
                }  
     
                default {
                    Write-verbose "Returning all" 
                    Write-verbose "Moref = $($V.Moref)"

                    $alarmmgr.getalarm( $V.MoRef ) #| foreach { Write-output (Get-View $_).info }
                }
            }
        }
    }
}

# -------------------------------------------------------------------------------------

function Copy-VMWareAlarm {

<#
    .SYNOPSIS
        Copy an Alarm to a different VMWare Object.

    .DESCRIPTION
        To make custom changes to an alarm for a specific object, the alarm needs to be created on that object.  This function will copy the alarm, meaning it doesn't have to be manually created.

        Once copied, the alarm can then be customized.

    .PARAMETER Alarm
        Alarm object to be copied

    .PARAMETER To
        Destination where the alarm should be copied

    .EXAMPLE
        Copies the Alarm-301 to all Datastore objects

        Get-VMWareAlarm -Level Datacenters -ID 'alarm-301' | Copy-VMWareAlarm -To (Get-Datastore) -Verbose

    .Links
        http://www.lucd.info/2010/02/20/alarms-moving-them-around/#more-1799

    .NOTES
        Author : Jeff Buenting
        Date : 2018 DEC 21

        I modified LUCD's function.  Credit goes to him for the original. (See Link)
#>

    [CmdletBinding()]
	param(
        [parameter (Mandatory=$True,ValueFromPipeline=$True)]
        [PSObject[]]$Alarm, 
         
        # ----- This can be any type of object that can have an alarm assigned to it.  It can also be an array.  Because it can be many types of objects, the parameter def is not strongly typed.
        $To
    )

    Begin {
        # ----- This temp var is used as the max length of the description field.  I am using it like this, so if Needed it is simpler to adjust and make it a parameter.
        $MaxLen = 80
    }
    
    Process {
        Foreach ( $A in $Alarm ) {
            Write-Verbose "Copy alarm $($A.Name)"
       
            # ----- Get AlarmManager object so we can manipulate the alarm objects
	        $alarmMgr = Get-View -ID AlarmManager
	        
            # ----- Creating New Alarm Object
	        $newAlarm = New-Object VMware.Vim.AlarmSpec
	        $newAlarm = $A

            # ----- store in a temp var otherwise the string gets long and funky
	        $oldName = $a.Name
	        $oldDescription = $a.Description

	        foreach($Dest in $To){
                Write-Verbose "     To $($Dest.Name)"
 
                # ----- the alarm gets saved to the Management Object Reference for the Destination.  So the destination needs to be converted to a view so the ref exists as an attribute
                $DestObj = $dest | Get-View

			    $suffix = " (" + $dest.Name + ")"

                write-verbose "Suffix = $Suffix"
                Write-Verbose "A.desc = $($A.Description)"

			    $newName = $oldName + $suffix

			    $newAlarm.Name = $newName
			    $newAlarm.Description = "$Suffix $OldDescription"

                # ----- truncate desc to less than max.  otherwise error thrown.
                if ( $NewAlarm.Description.length -gt $MaxLen ) { $newAlarm.Description = $newAlarm.Description.substring(0,$MaxLen-1) }

		        
                # ----- Not sure why this is here.  looks like it marks a depricated trigger as needing to change.
                $newAlarm.Expression.Expression | Foreach {
			        if($_.GetType().Name -eq "EventAlarmExpression"){
				        $_.Status = $null
				        $needsChange = $true
			        }
		        }

                # ----- Check if Alarm with that name already exists.  Skip if it does
                # ----- Ignoring error if the alarm does not exist
                if ( Get-AlarmDefinition -Name $newAlarm.Name -ErrorAction SilentlyContinue ) {
                    Write-Warning "Alarm already exists.  Skipping copy."
                }
                else {

                    $newAlarm

                    Write-verbose "Save Alarm to the destination"
                    $alarmMgr.CreateAlarm($destObj.MoRef,$newAlarm)
                }
	        }
        }
    }
}

# -------------------------------------------------------------------------------------
# Event Functions
# -------------------------------------------------------------------------------------

Function Get-VMWareEvent {

<#   
    .SYNOPSIS  
        Returns vSphere events    

    .DESCRIPTION 
        The function will return vSphere events. With
        the available parameters, the execution time can be
       improved, compered to the original Get-VIEvent cmdlet. 

    .NOTES  
        Author:  Luc Dekens   
        Update : Jeff Buenting

        I changed the made some changes to the script to add errro handling, default parameters and streamline some of the event filters.  I also changed the name to match my module.
        But most if not all credit to Luc Dekens.
        

    .PARAMETER Entity
       When specified the function returns events for the
       specific vSphere entity. By default events for all
       vSphere entities are returned. 

    .PARAMETER EventType
       This parameter limits the returned events to those
       specified on this parameter. 

    .PARAMETER Start
       The start date of the events to retrieve 
       Defaults to one day ago. ( -1 )

    .PARAMETER Finish
       The end date of the events to retrieve.
       Defaults to current date/time. 

    .PARAMETER Recurse
       A switch indicating if the events for the children of
       the Entity will also be returned 

    .PARAMETER User
       The list of usernames for which events will be returned 

    .PARAMETER System
       A switch that allows the selection of all system events. 

    .PARAMETER ScheduledTask
       The name of a scheduled task for which the events
       will be returned 

    .PARAMETER FullMessage
       A switch indicating if the full message shall be compiled.
       This switch can improve the execution speed if the full
       message is not needed.   

    .PARAMETER EventMax
        Max number of events to recieve.

    .EXAMPLE
       PS> Get-VMWareEventPlus -Entity $vm

    .EXAMPLE
       PS> Get-VMWareEventPlus -Entity $cluster -Recurse:$true

    .LINK
        http://www.lucd.info/2013/03/31/get-the-vmotionsvmotion-history/
#>
 
    [CmdletBinding()]
    param(
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$Entity = (Get-Datacenter),

        [string[]]$EventType,
        
        [DateTime]$Start = ((Get-Date).AddDays(-1)),
        
        [DateTime]$Finish = (Get-Date),
        
        [switch]$Recurse,
        
        [string[]]$User,
        
        [Switch]$System,
        
        [string]$ScheduledTask,
        
        [switch]$FullMessage = $false,

        [Int]$MaxEvent = 100
    )
 
    process {
        Try {
            Write-verbose "Creating Event Filter"
            $events = @()
            $eventMgr = Get-View EventManager -ErrorAction Stop
      
            # ----- Build event filter.
            $eventFilter = New-Object VMware.Vim.EventFilterSpec -ErrorAction Stop
            $eventFilter.disableFullMessage = ! $FullMessage
            $eventFilter.entity = New-Object VMware.Vim.EventFilterSpecByEntity -ErrorAction Stop
            $eventFilter.entity.recursion = &{if($Recurse){"all"}else{"self"}}
            $eventFilter.eventTypeId = $EventType

            # ----- Event Range
            $eventFilter.time = New-Object VMware.Vim.EventFilterSpecByTime -ErrorAction Stop
        
            if($Start){
                $eventFilter.time.beginTime = $Start
            }
        
            if($Finish){
                $eventFilter.time.endTime = $Finish
            }

            # ----- Filter by user or System
            if($User -or $System){
                $eventFilter.UserName = New-Object VMware.Vim.EventFilterSpecByUsername -ErrorAction Stop
        
                if($User){
                    $eventFilter.UserName.userList = $User
                }
        
                if($System){
                    $eventFilter.UserName.systemUser = $System
                }
            }
        
            # ----- Event filter on Scheduled task
            if($ScheduledTask){
                $si = Get-View ServiceInstance -ErrorAction Stop
                $schTskMgr = Get-View $si.Content.ScheduledTaskManager -ErrorAction Stop
                $eventFilter.ScheduledTask = Get-View $schTskMgr.ScheduledTask -ErrorAction Stop | where {$_.Info.Name -match $ScheduledTask} | Select -First 1 | Select -ExpandProperty MoRef
            }

            Write-Verbose "EventFilter = $($EventFilter | out-string)"
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Get-VMWareEvent : Error creating Event Filter.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }

        Write-Verbose "Entity = $($Entity | FL * | out-string)"

        Try {
            $entity | Foreach {
                Write-verbose "Getting Entities for $($_.name)"

                $eventFilter.entity.entity = $_.ExtensionData.MoRef

                $eventCollector = Get-View ($eventMgr.CreateCollectorForEvents($eventFilter))
                Write-verbose "EventCollector = $($eventCollector | gm | Out-string)"

                $eventsBuffer = $eventCollector.ReadNextEvents($MaxEvent)

                while($eventsBuffer){
                    Write-output $EventsBuffer
              #      $events += $eventsBuffer
                    $eventsBuffer = $eventCollector.ReadNextEvents($MaxEvent)
                }

                $eventCollector.DestroyCollector()
            }

 #           Write-Output $events
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Get-VMWareEvent : Error retrieving Events.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
    }
}



# -------------------------------------------------------------------------------------

Function Get-VMWareVMReconfiguration {

<#
    .Synopsis
        List VM Reconfigurations

    .Description
        audit changes made to a virtual machine

    .Parameter VM
        VM object or name.  can accept all events but will only process the VMReconfiguredEvents.

    .Example
        List changes in the month of November for the following vm: Server01

        (Get-VIEvent -Entity Server01) | Get-VMWareVMReconfiguration

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
        [PSObject[]]$VM
    )

    Process {
        Foreach ( $V in $VM ) {

            # ----- $VM can be either the VMName or a VM Object
            if ( $VM -isnot  [VMware.VimAutomation.ViCore.Impl.V1.VM.UniversalVirtualMachineImpl] ) {

                if ( $VM -is [System.String]) {
                    $V = Get-VM -Name $V
                }
                Else {
                    Throw "Get-VMWareVMReconfiguration : Requires a VM object or name."
                }
            }

            Write-verbose "Auditing $($V.name)"

            # ----- Get Events for This VM of type VMReconfiguredEvent
            Get-VMWareEvent -Entity $V -EventType 'VmReconfiguredEvent' | Foreach {

                Write-Verbose "Reconfigure event found" 

                $_.ConfigSpec.DeviceChange | Foreach {
			        if($_.Device -ne $null){
				        $Change = New-Object PSObject -Property @{
					        VMname = $E.VM.Name
					        Date = $E.CreatedTime
					        User = $E.UserName
					        Device = $_.Device.GetType().Name
					        Operation = $_.Operation
				        }

                        Write-Output $Change
			        }
		        }
            }
        }
    }
}

# -------------------------------------------------------------------------------------

function Get-VMWareMotionHistory {

<#   
    .SYNOPSIS  
        Returns the vMotion/svMotion history    
    
    .DESCRIPTION 
        The function will return information on all
        the vMotions and svMotions that occurred over a specific
        interval for a defined number of virtual machines 
    
    .NOTES  
        Author:  Luc Dekens 
        Update : Jeff Buenting

        I changed this script quite a bit.  Removed all of the formatting.  I felt it should return the same type of object as the Get-VMWareEvent did.  I also changed the date parameters to again
        match up with the Get-VMWareEvent.
          
    .PARAMETER Entity
       The vSphere entity. This can be one more virtual machines,
       or it can be a vSphere container. If the parameter is a
        container, the function will return the history for all the
       virtual machines in that container. 
 
    .PARAMETER Start
       The start date of the events to retrieve 
       Defaults to one day ago. ( -1 )

    .PARAMETER Finish
       The end date of the events to retrieve.
       Defaults to current date/time. 

    .PARAMETER Recurse
       A switch indicating if the events for the children of
       the Entity will also be returned 
    
    .EXAMPLE
       PS> Get-MotionHistory -Entity $vm -Days 1
    
    .EXAMPLE
       PS> Get-MotionHistory -Entity $cluster -Sort:$false
    
    .EXAMPLE
       PS> Get-Datacenter -Name $dcName |
       >> Get-MotionHistory

    .LINK
        http://www.lucd.info/2013/03/31/get-the-vmotionsvmotion-history/
#>
 
    [CmdletBinding()]
    param(   
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl[]]$Entity,
        
        [DateTime]$Start = ((Get-Date).AddDays(-1)),
        
        [DateTime]$Finish = (Get-Date),
        
        [switch]$Recurse = $false,

        [switch]$Sort = $true
    )
 
    begin{
    $history = @()
        
    $eventTypes = "DrsVmMigratedEvent","VmMigratedEvent"
    }
 
    process{
        Write-Output (Get-VMWareEvent -Entity $entity -Start $start -Finish $Finish -EventType $eventTypes -Recurse:$Recurse)
    }
 
}

# -------------------------------------------------------------------------------------
# DataStore Functions
# -------------------------------------------------------------------------------------


function Get-VMWareDataStoreSIOC {
    
<#
    .SYSNOPSIS
        Returns on object with SIOC information from a VMWare Datastore.
#>

    [CmdletBinding()]
    Param (
        # ----- the vmfsdatastore class does not have a 'constructor' so I haven't figured out how to mock it in Pester.  Thus using the Custom object and accepting a string as well.
        [Parameter (Mandatory = $True,ValueFromPipeline = $True,Position = 0)]
        [PSObject[]]$DataStore
    )

    Process {
        Foreach ( $DS in $DataStore ) {

            # ----- DataStore Ojbect?
            if ( $DS.GetType().FullName -eq 'VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore' ) {
                Write-Verbose "DataStore Object"
            }
            ElseIf ( $DS.GetType().FullName -eq 'System.String' ) {
                Write-Verbose "DataStore Name.  Getting object"

                $DS = Get-Datastore -Name $DS
            }
            Else {
                Write-Verbose "Unknown object"

                Throw "Get-VMWareDataStore : DataStore needs to be a datastore object or the name of the datastore."
            }

            Write-Verbose "Getting SIOC info for $($DS.Name)"

            # ----- Convert to View object of the datastore
            $DSView = Get-View -VIObject $DS

            $SIOCInfo = [PSCustomObject]@{
                Name = $DS.Name
                Enabled = $DSView.IORMConfiguration.Enabled
                congestionThresholdMode = $DSView.IORMConfiguration.CongestionThresholdMode
                CongestionThreshold = $DSView.IORMConfiguration.CongestionThreshold
                PercentOfPeakhroughput = $DSView.IORMConfiguration.PercentofPeakThroughput
                StatsCollectionEnabled = $DSView.IORMConfiguration.StatsCollectionEnabled
                ReservationEnabled = $DSView.IORMConfiguration.ReservationEnabled
                StatsAggregationDisabled = $DSView.IORMConfiguration.StatsAggregationDisabled
                ReservableIOPSThreshold = $DSView.IORMConfiguration.ReservableIopsThreshold
            }

            Write-Output $SIOCInfo
        }
    }
        
}

# -------------------------------------------------------------------------------------

function Set-VMWareDataStoreSIOC {

<#
    .SYNOPSIS
        Makes changes to a datastores SIOC configuration

    .LINK
        https://github.com/vmware/PowerCLI-Example-Scripts/blob/master/Scripts/DatastoreSIOCStatistics.ps1
#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True,ValueFromPipeline = $True,Position = 0)]
        [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.VmfsDatastore[]]$DataStore,

        [Bool]$Enabled,

        [Bool]$StatsOnlyMode

    )

    Process {
        Foreach ( $DS in $DataStore ) {
            Write-Verbose "Configuring SIOC info for $($DS.Name)"

            $StorResourceManView = Get-View -id 'StorageResourceManager-StorageResourceManager'
            
            $spec = New-Object vmware.vim.storageiormconfigspec

            if ( -Not ([string]::IsNullOrEmpty( $Enabled )) ) {

                if ($Enable) {
                    Write-Verbose "Enabling SIOC with Stats Collection"

                    $spec.Enabled = $true
                    $Spec.StatsCollectionEnabled = $True

                } 
                Else {
                    Write-Verbose "Disabling SIOC and Stats Collection"

                    $spec.Enabled = $false
                    $Spec.StatsCollectionEnabled = $False
                }
            }

            

            if ( -Not ([string]::IsNullOrEmpty($StatsOnlyMode)) ) {
                Write-Verbose "StatsOnlyMode = $StatsOnlyMode"

                if ( $StatsOnlyMode ) {
                    Write-Verbose "Enabling Stats Only Mode"

                    $spec.Enabled = $false
                    $Spec.StatsCollectionEnabled = $True
                }
                Else {
                    Write-Verbose "Disabling Stats Only Mode (Disable all)"

                    $spec.Enabled = $false
                    $Spec.StatsCollectionEnabled = $False
                }
            }

            Write-Verbose "Saving SIOC Config"
            $StorResourceManView.ConfigureDatastoreIORM_Task($ds.ExtensionData.MoRef,$spec) | out-null
        }
    }
}


# -------------------------------------------------------------------------------------
# Log Functions
# -------------------------------------------------------------------------------------

Function Get-VMWareHostLogList {

<#
    .SYNOPSIS
        Retrieves a list of existing log files on an ESX host.

    .DESCRIPTION
        This function is used to obtain a list of log files located in the default location of a VMWare ESX server (/var/log/)

    .PARAMETER SSHSession
        SSHSession object created with POSH SSH New-SSHSession

    .EXAMPLE
        List all logs on server $Server.

        $SSH = New-SSHSession -ComputerName $Server -Credential $RootCred --AcceptKey -KeepAliveInterval 5
        $LogNames = Get-VMWareHostLogList -SSHSession $SSH

    .Notes
        Requires POSH SSH

        Author : Jeff Buenting
        Date : 2019 JAN 29
#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [SSH.SshSession[]]$SSHSession
    )

    Process {
        Foreach ( $S in $SSHSession ) {
            Write-Verbose "Retrieving List of Log files from $($S.Host)"

            $Result = invoke-sshcommand -SessionId $ssh.SessionID -Command "ls var/log/*.log"

            Write-output $Result.output
        }
    }
}

#--------------------------------------------------------------------------------------

Function Get-VMWareHostLog {

<#
    .SYNOPSIS
        Retrieves the log file data from an ESX server.

    .DESCRIPTION
        This function is used to obtain the data entries in a VMWare ESX host server log file.

    .PARAMETER SSHSession
        SSHSession object created with POSH SSH New-SSHSession

    .PARAMETER LogName
        Name of the log to retrieve.

    .EXAMPLE
        Retrieve the FDM.Log data from $Server.

        $SSH = New-SSHSession -ComputerName $Server -Credential $RootCred -AcceptKey -KeepAliveInterval 5
        $Log = Get-VMWareHostLog -SSHSession $SSH -LogName FDM.Log

    .Notes
        Requires POSH SSH

        Author : Jeff Buenting
        Date : 2019 JAN 29
#>

    [CmdletBinding()]
    Param (
        [Parameter (Mandatory = $True)]
        [SSH.SshSession]$SSHSession,

        [Parameter (Mandatory = $True)]
        [String]$LogName

    )

    Process {
        Foreach ( $L in $LogName ) {
            Write-Verbose "Retrieving Log file $L from $($S.Host)"

            Write-Output (invoke-sshcommand -SessionId $ssh.SessionID -Command "cat var/log/$L")
        }
    }
}

# -------------------------------------------------------------------------------------

function Get-VMWareVMLog {

<#
    .SYNOPSIS
        Retrieve the virtual machine logs

    .DESCRIPTION
        The function retrieves the logs from one or more virtual machines and stores them in a local folder

    .NOTES
        Author:  Luc Dekens
        Jeff Buenting:  I modified this to fit my needs.  added some error handling etc.  But credit goes to Luc Dekens.

    .PARAMETER VM
        The virtual machine(s) for which you want to retrieve the logs.

    .PARAMETER Path
        The folderpath where the virtual machines logs will be stored. The function creates a folder with the name of the virtual machine in the specified path.

    .EXAMPLE
        PS> Get-VMLog -VM $vm -Path "C:\VMLogs"

    .EXAMPLE
        PS> Get-VM | Get-VMLog -Path "C:\VMLogs"

    .LINKS
        http://www.lucd.info/2011/02/27/virtual-machine-logging/
#>

    param(
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject[]]$VM,

        [parameter(Mandatory=$true)]
        [string]$Path
    )

    process{
        foreach($obj in $VM){
            if($obj.GetType().Name -eq "string"){
                $obj = Get-VM -Name $obj
            }
        }

        $logPath = $obj.Extensiondata.Config.Files.LogDirectory
        Write-Verbose "LogPath = $LogPath"

        $dsName = $logPath.Split(']')[0].Trim('[')
        $vmPath = $logPath.Split(']')[1].Trim(' ')

        # ----- what if the datastore name is used in more than one datacenter?
        $Datacenter = $Obj | Get-datacenter | Select-object -ExpandProperty Name

        $ds = Get-Datastore -Name $dsName -Location $Datacenter
        $drvName = "MyDS" + (Get-Random)

        New-PSDrive -Location $ds -Name $drvName -PSProvider VimDatastore -Root '\' | Out-Null
        Copy-DatastoreItem -Item ($drvName + ":" + $vmPath + "*.log") -Destination ($Path + "\" + $obj.Name + "\") -Force:$true
        Remove-PSDrive -Name $drvName -Confirm:$false
    }
}


# -------------------------------------------------------------------------------------
# Misc Tools
# -------------------------------------------------------------------------------------

Function Get-VMWareRamdisk {

<#
    .SYNOPSIS
        Retrieves information about the Ramdisk on a VMWARE ESXi host.

    .DESCRIPTION
        Use this function to gather information about the RAMdisks that are on a VMWare ESXi host.  This information is helpful for troubleshooting.

    .PARAMETER VMHost
        VMWare Host object.  Use Get-VMHost to obtain this information.

    .EXAMPLE
        Return all ramdisk info for all vmware hosts.

        Get-VMHost | Get-VMWARERamDisk

    .NOTES
        Author : Jeff Buenting
        Date : 2019 APR 01
#>

    [CmdletBinding()]
    Param (
        [Parameter ( Mandatory = $True, ValueFromPipeline = $True )]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl]$VMHost
    )

    Process {
        Foreach ( $H in $VMHost ) {
            Write-verbose "Getting Ramdisk infor for $($H.Name)"

            $ESXCLI = Get-ESXCLI -VMHost $H.Name -V2

            $RAMDisk = $ESXCLI.system.visorfs.ramdisk.list.invoke()

            $RAMDisk | Add-Member -MemberType NoteProperty -Name VMHost -Value $H.Name

            Write-Output $RAMDisk
        }
    }
}

# -------------------------------------------------------------------------------------

Function Test-VMWareHostConnection {

<#
    .SYNOPSIS 
        VMKping or ping via ESXCLI

    .DESCRIPTION
        I got tired of doing this manually so I created this function to  build and do it for me. It will ping using either ESXCLI or VMKPing via SSH.

    .PARAMETER VMHost
        IP of the host to ping from.

    .PARAMETER IPAddress
        IP of the destination that is being pinged.

    .PARAMETER SSH
        SSH Session object for the VMHost.  Obtained with using New-SSHSession from Posh-SSH.

    .PARAMETER VMKernelPort
        VMKernel Interface the ping will be sent out.

    .PARAMETER Count
        Number of pings.

    .EXAMPLE
        Ping by SSH into Host.

        $RootCred = get-credential

        $SSH = New-SSHSession -ComputerName $Server -Credential $RootCred -AcceptKey -KeepAliveInterval 5

        $Result = Test-vmwarehostconnection -SSH $SSH -IPAddress 192.168.1.85 -VMKernelPort vmk3 -Verbose

        $Result.output

        Remove-SSHSession $SSH

    .NOTES
        Requires the POSH SSH Module

        Author : Jeff Buenting
        Date : 2019 JAN 31

#>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param (
        [Parameter (ParameterSetName = 'Default',Mandatory = $True,ValueFromPipeline = $True)]
        [PSObject]$VMHost,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'VMKPing')]
        [String[]]$IPAddress,

        [Parameter (ParameterSetName = 'VMKPing',Mandatory = $True)]
        [SSH.SshSession]$SSH,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'VMKPing')]
        [String]$VMKernelPort,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'VMKPing')]
        [String]$Count = 4
    )

    if ( $PSCmdlet.ParameterSetName -eq 'VMKPing' ) {
        Write-verbose "Ping via SSH and VMKPing"

        $Options = "-c $Count"

        # ----- VMKernel is case sensitive and all lower case
        if ( $VMKernelPort ) { $Options = "$Options -I $($VMKernelPort.ToLower())" }

        Write-Verbose "vmkping $Options $IPAddress"
        $Result = invoke-sshcommand -SessionId $ssh.SessionID -Command "vmkping $Options $IPAddress"
    }
    Else {
        Write-verbose "Ping via ESXCLI"

        $EsxCli = Get-EsxCli -VMHost $VMHost -V2

        # ----- Configure arguments for command
        $params = $esxcli.network.diag.ping.createArgs()
        $Params.Host = $IPAddress
        $Params.Count = $Count
        if ( $VMKernelPort ) { $Params.interface = $VMKernelPort }

        Try {
            $Result = $EsxCli.network.diag.ping.invoke($Params)
        }
        Catch {
            $ExceptionMessage = $_.Exception.Message
            $ExceptionType = $_.Exception.GetType().Fullname
            Throw "Test-VMWareHostConnection : Error attempting to ping via ESXCLI.`n`n     $ExceptionMessage`n`n $ExceptionType"
        }
    }

    Write-output $Result
}

# -------------------------------------------------------------------------------------
# Share functions
# -------------------------------------------------------------------------------------

Function Get-VMWareResourceShare {
    
<#
    .SYNOPSIS
        Returns an object with the shares and resource percentages.
 
    .DESCRIPTION
        Returns a list of object with resource share values.
 
    .PARAMETER Cluster
        Name or object of a cluster that we want to obtain share info.
 
    .PARAMETER ResourcePool
        Name or object of a resource pool that we want to obtain share info.
 
    .EXAMPLE
        Return Share info for CLUSTER
 
        Get-VMWareResourceShare -Cluster CLUSTER
 
    .NOTES
        Author : Jeff Buenting
        Date : 2019 FEB 26
#>
 
    [CmdletBinding()]
    Param (
        [Parameter ( Mandatory = $True,ParameterSetName = 'Cluster' ) ]
        [PSObject]$Cluster,
 
        [Parameter ( Mandatory = $True,ParameterSetName = "ResourcePool" ) ]
        [PSObject]$ResourcePool,
 
        [Parameter ( ParameterSetName = "ResourcePool" ) ]
        [PSObject]$VMHostName = '*',
 
        [Parameter ( Mandatory = $True,ParameterSetName = "VMHost" ) ]
        [PSObject]$VMHost
    )
 
    Switch ( $PSCmdlet.ParameterSetName ) {
        'Cluster' {
 
            Write-Verbose "Cluster Parameter Set"
 
            if ( $Cluster.GetType().Name -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.ClusterImpl' ) {
                Write-Verbose "geting cluster object"
 
                $Cluster = Get-cluster -name $Cluster
            }
 
            # ----- Get Child resource pools
            $Cluster | Get-ResourcePool | where Parent -like Resources | foreach {
                Write-Verbose "Getting Shares for $($_.Name)"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $_.Name 
                    CpuSharesLevel = $_.CPUSharesLevel
                    MemSharesLevel = $_.MemSharesLevel
                    NumCPUShares = $_.NumCPUShares
                    NumMemShares = $_.NumMemShares
                    ResourceType = 'ResourcePool'
                    Parent = $_.parent
                })   
 
                # ----- Get Children of the child resource pool
                $ChildResources =  Get-VMWareResourceShare -ResourcePool $_.Name 
 
                if ( $ChildResources ) {
                    Write-Verbose "Resource has Children"
 
                    Write-Output $ChildResources
                    
                    Write-Verbose $($Obj | Out-String )
 
                    Write-Output $Obj 
                }
                Else {
                    Write-Verbose "Resource has no Children."
                }
            }
 
            # ----- Get VMs in this Resource pool (Resources)
            $Cluster | Get-VM | where { ($_.ResourcePool -like 'Resources') -and ($_.PoweredState -ne 'PoweredOff')} | foreach {
                $R = $_ | Get-VMResourceConfiguration 
                Write-Verbose "Getting Shares for $($_.Name)"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $R.VM 
                    CpuSharesLevel = $R.CPUSharesLevel
                    MemSharesLevel = $R.MemSharesLevel
                    NumCPUShares = $R.NumCPUShares
                    NumMemShares = $R.NumMemShares
                    ResourceType = 'VM'
                    Parent = $_.ResourcePool
                }) 
 
                Write-Verbose $($Obj | Out-String )
 
                Write-Output $Obj
 
                Write-Verbose "-----VM"
            }  
        }
 
        'ResourcePool' {
            Write-Verbose "Resource Pool Parameter Set"
 
            if ( $ResourcePool.GetType().Name -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.ResourcePoolImpl' ) {
                Write-Verbose "geting Resource Pool object for $ResourcePool"
 
                $ResourcePool = Get-ResourcePool -Name $ResourcePool
            }
 
            Write-Verbose $($ResourcePool | out-string)
 
            $ResourcePool | Get-ResourcePool | where Parent -like $ResourcePool.Name | foreach {
                Write-Verbose "Getting Shares for $($_.Name) on $VMHostName"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $_.Name 
                    CpuSharesLevel = $_.CPUSharesLevel
                    MemSharesLevel = $_.MemSharesLevel
                    NumCPUShares = $_.NumCPUShares
                    NumMemShares = $_.NumMemShares
                    ResourceType = 'ResourcePool'
                    Parent = $_.parent
                })   
 
                # ----- Get Children of the child resource pool
                $ChildResources =  Get-VMWareResourceShare -ResourcePool $_.Name -VMHostName $VMHostName
 
                if ( $ChildResources ) {
                    Write-Verbose "Resource has Children"
 
                    Write-Output $ChildResources
                    
                    Write-Verbose $($Obj | Out-String )
 
                    Write-Output $Obj 
                }
                Else {
                    Write-Verbose "Resource has no Children."
                }
            }
 
            # ----- Get VMs in this Resource pool (Resources)
            $ResourcePool | Get-VM | where { ($_.ResourcePool -like $ResourcePool.Name) -and ($_.VMHost -Like $VMHostName) -and ($_.PoweredState -ne 'PoweredOff')} | foreach {
                Write-Verbose "Getting VM Object info "
 
                $R = $_ | Get-VMResourceConfiguration 
                Write-Verbose "Getting Shares for $($_.Name)"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $R.VM 
                    CpuSharesLevel = $R.CPUSharesLevel
                    MemSharesLevel = $R.MemSharesLevel
                    NumCPUShares = $R.NumCPUShares
                    NumMemShares = $R.NumMemShares
                    ResourceType = 'VM'
                    Parent = $_.ResourcePool
                }) 
 
                Write-Verbose $($Obj | Out-String )
 
                Write-Output $Obj
 
                Write-Verbose "-----VM"
            }  
        }
 
        'VMHost' {
            Write-Verbose "VMHost Parameter Set"
 
            if ( $VMHost.GetType().Name -ne 'VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl' ) {
                Write-Verbose "geting VM Host object for $VMHost"
 
                $VMHost = Get-VMHost -Name $VMHost
            }
 
            Get-Cluster -VMHost $VMHost | Get-ResourcePool | where Parent -like 'Resources' | foreach {
                Write-Verbose "Getting Shares for $($_.Name)"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $_.Name 
                    CpuSharesLevel = $_.CPUSharesLevel
                    MemSharesLevel = $_.MemSharesLevel
                    NumCPUShares = $_.NumCPUShares
                    NumMemShares = $_.NumMemShares
                    ResourceType = 'ResourcePool'
                    Parent = $_.parent
                })   
 
                # ----- Get Children of the child resource pool
                $ChildResources =  Get-VMWareResourceShare -ResourcePool $_.Name -VMHostName $VMHost.Name 
 
                if ( $ChildResources ) {
                    Write-Verbose "Resource has Children"
 
                    Write-Output $ChildResources
                    
                    Write-Verbose $($Obj | Out-String )
 
                    Write-Output $Obj 
                }
                Else {
                    Write-Verbose "Resource has no Children."
                }
 
                
            }
 
            # ----- Get VMs in this Resource pool (Resources)
            $VMHost | Get-VM | where { ($_.ResourcePool -like 'Resources') -and ($_.PoweredState -ne 'PoweredOff')} | foreach {
                Write-Verbose "Getting VM Object info"
 
                $R = $_ | Get-VMResourceConfiguration 
                Write-Verbose "Getting Shares for $($_.Name)"
                $Obj = New-Object -TypeName PSObject -Property (@{
                    Name = $R.VM 
                    CpuSharesLevel = $R.CPUSharesLevel
                    MemSharesLevel = $R.MemSharesLevel
                    NumCPUShares = $R.NumCPUShares
                    NumMemShares = $R.NumMemShares
                    ResourceType = 'VM'
                    Parent = $_.ResourcePool
                }) 
 
                Write-Verbose $($Obj | Out-String )
                
                Write-Output $Obj
 
                Write-Verbose "-----VM"
            }  
        }
    }
}
 
# ---------------------------------------------------------------------------------------
 
Function CalculateVMWareResourceSharePercentageHelper {
    
<#
    .SYNOPSIS
        Helper function to recursively calculate
 
    .NOTE
        Helper Function
#>
 
    [CmdletBinding()]
    param (
        [PSObject]$Groups,
 
        [String]$Root,
 
        [String]$ParentCPUPercentage = 100,
 
        [String]$ParentMEMPercentage = 100
    )
    
    # ----- Determine if there are any Resource pool children
    $Parent = $Root      
 
    Write-Verbose "Parent = $Parent"
 
    if ( ($Groups | Where Name -eq $Parent).Group.count -gt 0 ) {
 
        # ----- Process items in each group
        $TotCPUShares = ( $Groups | where Name -eq $Parent).Group | Measure-Object -Property NumCPUShares -Sum | Select-object -ExpandProperty sum
        $TotMemShares = ( $Groups | Where Name -eq $Parent).Group | Measure-Object -Property NumMemShares -Sum | Select-object -ExpandProperty sum
 
        Write-Verbose "TotalCPUShares = $TotCPUShares"
        Write-Verbose "TotalMEMShares = $TotMEMShares"
 
        ($Groups | Where Name -eq $Parent).Group | Foreach {
             
            $G = $_
            # ----- this calc finds the percentage a resource has of the Resource pool.  so it is a percentage of a percentage of total.
            $G | Add-Member -MemberType NoteProperty -Name CPUPercent -Value ((($G.NumCPUShares / $TotCPUShares) * 100 ) * ($ParentCPUPercentage/100)) -Force
            $G | Add-Member -MemberType NoteProperty -Name MemPercent -Value ((($G.NumMemShares / $TotMemShares) * 100 ) * ($ParentMEMPercentage/100)) -Force
 
            Write-Output $G
 
            if ( $G.ResourceType -eq 'ResourcePool' ) {
                 Write-Output (CalculateVMWareResourceSharePercentageHelper -Groups $Groups -Root $G.Name -ParentCPUPercentage $G.CPUPercent -ParentMEMPercentage $G.MEMPercent)
            }
 
        }
 
    }
}
 
# ---------------------------------------------------------------------------------------
 
Function Find-VMWareResourceSharePercentage {
 
<#
    .SYNOPSIS
        Calculates the Share Percentage for each level
 
    .DESCRIPTION
        Calculates the share percentages for each resource.
 
    .PARAMETER Resource
        Resource object created with Get-VMWareResourceShare
 
    .PARAMETER Root
        Hierarchy Root.  By default this is the hidden resource pool, Resources.  By including this you have the option to calculate using any Resource pool as the root.
 
    .EXAMPLE
        retireve VM share percentages from one vmware host in a cluster.
 
        Get-VMWareResourceShare -VMHost ESXI02 | Find-VMWareesourceSharepercentage
 
    .NOTE
        This function and the helper CalculateVMWareResourceSharePercentageHelper function have been split up as we need all resource objects prior to calculations.  The only way I could figure out how to accomplish this was with the functions being split
        and when the objects are piped in collecting them and performing the calculations afterwards.
 
    .NOTE
        Author : Jeff Buenting
        Date: 2019 FEB 27
 
#>
 
    [CmdletBinding()]
    param (
        [Parameter (Mandatory = $True, ValueFromPipeline = $True)]
        [PSObject]$Resource,
 
        [String]$Root = 'Resources'
    )
 
    Begin {
        $Resources =@()
    }
 
    Process {
        # ----- Collect all Resources from the pipeline
        $Resources += $Resource
    }
 
    End {
        # ----- Separate by level and calculate shares
        write-verbose "Grouping collected Resources"
        $Groups = $Resources | Group-Object -Property Parent 
 
        Write-Output (CalculateVMWareResourceSharePercentageHelper -Groups $Groups -Root $Root -Verbose:$VerbosePreference) 
        
    }
} 


