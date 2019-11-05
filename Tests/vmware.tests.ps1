# ----- Get the module name
if ( -Not $PSScriptRoot ) { $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }

$ModulePath = $PSScriptRoot.trim( '\Tests' )

Write-output "ModulePath = $ModulePath"

$Global:ModuleName = $ModulePath | Split-Path -Leaf

Write-Output "ModuleName = $ModuleName"

# ----- Remove and then import the module.  This is so any new changes are imported.
Get-Module -Name $ModuleName -All | Remove-Module -Force

Import-Module "$ModulePath\$ModuleName.PSD1" -Force -ErrorAction Stop  

InModuleScope $ModuleName {

    #-------------------------------------------------------------------------------------
    # ----- Check if all fucntions in the module have a unit tests

    Describe "$ModuleName : Module Tests" {

        $Module = Get-module -Name $ModuleName -Verbose

        $testFile = Get-ChildItem -Path $module.ModuleBase,"$($Module.ModuleBase)\Tests" -Filter '*.Tests.ps1' -File -verbose
    
        $testNames = Select-String -Path $testFile.FullName -Pattern 'Describe "\$ModuleName : (.*)"' | ForEach-Object {
              $_.matches.groups[1].value
        }
 
        $moduleCommandNames = (Get-Command -Module $ModuleName | where CommandType -ne Alias)
 
        it 'should have a test for each function' {
            Compare-Object $moduleCommandNames $testNames | where { $_.SideIndicator -eq '<=' } | select inputobject | should beNullOrEmpty
        }
    }

    #-------------------------------------------------------------------------------------
    # Call separate function tests

    $PesterResults = @()

    # ----- -exclude was not working so used the where clause
    Get-ChildItem -path $ModulePath\Tests -Filter *.tests.ps1  | where Name -ne "$ModuleName.Tests.ps1" | foreach {
        $PesterResults += Invoke-Pester -Script $_.FullName -PassThru
    }

    #-------------------------------------------------------------------------------------
    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareAlarm" -Tags Alarm {
    
        # ----- Mocks
        Mock -Command Get-View -ParameterFilter { $ID -eq 'AlarmManager' } -MockWith {
            $Obj = New-Object -TypeName PSObject 

            $Obj | Add-Member -MemberType ScriptMethod -Name GetAlarm -Value {
                Param ( $MoRef )


                $AlarmObj = New-Object -TypeName PSObject -Property {}

                Return $AlarmObj
            } 

            Return $Obj
        }

        Mock -Command Get-View -ParameterFilter { $VIObject } -MockWith {
            $Obj = New-Object -TypeName PSObject -Property (@{
                MoRef = 'Test-Test-01'
            })

            Return $Obj
        }

        # ----- if pester is older than 3.4.4, New-MockObject does not exist, so can't test
        $V = (Get-Module -Name Pester).Version
        if (  "$($V.Major).$($V.Minor).$($V.Build)" -ge "3.4.4" ) { 

            $DS = New-MockObject -Type 'VMware.VimAutomation.ViCore.Impl.V1.DatastoreManagement.VmfsDatastoreImpl'

            Context Execution {
            }

            Context Output {
                It "Should Accept pipeline input and return an Alarm object" {
                    $DS | Get-VMWareAlarm | Should BeofType PSObject
                } -pending

                It "Should accept positional input and return an Alarm object" {
                    $DS | Get-VMWareAlarm | Should BeofType PSObject
                } -pending
            }
        }
        Else {
            Write-Warning "Test uses New-MockObject which requires Pester version 3.4.4 or higher"
        }
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Copy-VMWareAlarm" -Tags Alarm {

        # ----- Mocks
        Mock -Command Get-View -ParameterFilter { $ID -eq 'AlarmManager' } -MockWith {
            $Obj = New-Object -TypeName PSObject 

            $Obj | Add-Member -MemberType ScriptMethod -Name GetAlarm -Value {
                Param ( $MoRef )

                $AlarmObj = New-Object -TypeName PSObject -Property {}

                Return $AlarmObj
            } 

            Return $Obj
        }

        Mock -CommandName New-Object -ParameterFilter { $TypeName -eq 'VMware.Vim.AlarmSpec' } -MockWith {
            $Obj = @{
                Name = $Null
                Description = $Null
            }

            Return $Obj
        }

       Context Execution {

            # ----- cannot mock PowerCLI objects
            # https://github.com/pester/Pester/issues/803

            It "Cannot mock PowerCLI Cmdlets ( https://github.com/pester/Pester/issues/803 )" {
  
                $True | Should be $True
            }
        }

    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareEvent" -Tags Event {

        # ----- Mocks
        Mock -CommandName Get-Datacenter -MockWith {}


        Mock -Command Get-View -ParameterFilter { $ID -eq 'EventManager' } -MockWith {
            $OBJ = @{}

            $OBJ | Add-member -MemberType ScriptMethod -Name CreateCollectorForEvents -Value {
                Param ($eventFilter)

                Write-Output 'CreateCollectorForEvents'
            }

            Return $OBJ
        }

        Mock -Command Get-View -ParameterFilter { $ID -eq 'ServiceInstance' } -MockWith {

            $ContentOBJ = @{
                ScheduledTaskManager = 'SchedTaskMGR'
            }

            $Obj = @{
                Content = $ContentObj
            }

            return $OBJ
        }

        Mock -Command Get-View -ParameterFilter { $ID -eq 'SchedTaskMGR' } -MockWith {
            $Obj = @{
                ScheduledTask = 'ScheduledTask'
            }

            Return $OBJ
        }

        Mock -Command Get-View -ParameterFilter { $ID -eq 'SchedTask' } -MockWith {
            $NameOBJ = @{
                Name = 'Task'
            }

            $Obj = @{
                info = $NameObj
                MoRef = 'MoRef'
            }

            Return $OBJ
        }

        Mock -Command Get-View -ParameterFilter { $ID -eq 'CreateCollectorForEvents' } -MockWith {
            $OBJ = @{}

            $OBJ | Add-Member -MemberType ScriptMethod -Name ReadNextEvents -Value {
                Param ($eventnumber)
            }

            $OBJ | Add-Member -MemberType ScriptMethod -Name DestroyCollector -Value { }

            Return $OBJ
        }

        Mock -Command New-Object -ParameterFilter { $TypeName -eq 'Vim.EventFilterSpecByEntity' } -MockWith {
            $obj = @{
                Recursion = 'self'
            }

            Return $OBJ
        }

        Mock -Command New-Object -ParameterFilter { $TypeName -eq 'VMware.Vim.EventFilterSpecByTime' } -MockWith {
            $obj = @{
                begintime = $Null
                EndTime = $Null
            }

            Return $OBJ
        }

        Mock -Command New-Object -ParameterFilter { $TypeName -eq 'VMware.Vim.EventFilterSpecByUsername' } -MockWith {
            $obj = @{
                UserList = $Null
                SystemUser = $Null
            }

            Return $OBJ
        }

        Mock -Command New-Object -ParameterFilter { $TypeName -eq 'VMware.Vim.EventFilterSpec' } -MockWith {
            $EntityOBJ = @{
                Entity = $Null
            }
            
            $obj = @{
                disableFullMessage = $Null
                Entity = $EntityOBJ
                EventTypeID = $Null
                Time = $Null
                UserName = $Null
                ScheduledTask = $Null
            }

            Return $OBJ
        }

        Context Execution {
            It "Should throw an error if there is one" {
                { Get-VMWareEvent } | Should Throw
            } -Pending

            It "Should not throw an error if there is not one" {
                { Get-VMWareEvent } | Should Not Throw
            } -Pending
        }

        Context Output {

            # ----- cannot mock PowerCLI objects
            # https://github.com/pester/Pester/issues/803

            It "Cannot mock PowerCLI Cmdlets ( https://github.com/pester/Pester/issues/803 )" {
                $True | Should be $True
            } -pending

   #         It "Should return an Event object " {
   #             Get-VMWareEvent -Verbose | Should beoftype "*Event"
   #         }
        }
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareVMReconfiguration" -Tags Event {

        # ----- if pester is older than 3.4.4, New-MockObject does not exist, so can't test
        $V = (Get-Module -Name Pester).Version
        if (  "$($V.Major).$($V.Minor).$($V.Build)" -ge "3.4.4" ) { 

            $Event = New-MockObject -Type VMWare.Vim.VmReconfiguredEvent
        
            Context Execution {
                It "Cannot mock PowerCLI Cmdlets ( https://github.com/pester/Pester/issues/803 )" {
                    $True | Should be $True
                }
            }
        }
        Else {
            Write-Warning "Test uses New-MockObject which requires Pester version 3.4.4 or higher"
        }

    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareMotionHistory" -Tags Event {
    
        # ----- if pester is older than 3.4.4, New-MockObject does not exist, so can't test
        $V = (Get-Module -Name Pester).Version
        if (  "$($V.Major).$($V.Minor).$($V.Build)" -ge "3.4.4" ) { 

            # ----- Mocks
            Mock -CommandName Get-VMWareEvent -ParameterFilter { $Entity -and $start -and $Finish -and $eventTypes -and $Recurse } -MockWith {
                Return (New-Object -TypeName PSObject)
            }

     #       $VM = New-MockObject -type VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl 

            Context Output {
                It "Should return VMWare Event object" {
                    Get-VMWareMotionHistory -Entity $VM  | Should beoftype PSOBject
                } -pending
            }

        }
        Else {
            Write-Warning "Test uses New-MockObject which requires Pester version 3.4.4 or higher"
        }
    }


    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    
    #-------------------------------------------------------------------------------------

    Describe "$ModuleName : Get-VMWareDataStoreSIOC" {

        Mock -CommandName Get-DataStore -ParameterFilter { $Name } -MockWith {
            $Obj = [PSCustomObject]@{
                Name = 'TestDS'
            }

            Return $Obj
        }

        # ----- For some reason this does notwork.  The mock is never called it still calls the original function
        Mock -CommandName Get-View -ParameterFilter { $VIObject } -MockWith {

            $SIOCInfo = [PSCustomObject]@{
                Enabled = 'False'
                congestionThresholdMode = 'automatic'
                CongestionThreshold = 30
                PercentOfPeakhroughput = 90
                StatsCollectionEnabled = 'True'
                ReservationEnabled = 'True'
                StatsAggregationDisabled = 'True'
                ReservableIOPSThreshold = $Null
            }

            Return $SIOCInfo
        } -Verifiable
   
        Context 'Input' {
            It 'Should accept pipeline input' {
                Get-VMWaredataStoreSIOC -DataStore 'test' -verbose | Should beoftype PSCustom

                Assert-MockCalled
            } -Pending

            It 'Should accept an array as input' {
                Get-VMWaredataStoreSIOC -DataStore 'test' | Should beoftype PSCustom
            } -Pending

            It 'Should not accept input from objects other than string or vmfsDataStore' {
                $OBJ = [PSCustomObject]@{ Name = 'test' }

                { $OBJ | Get-VMWareDataStoreSIOC } | Should Throw
            }

        }

        It "Returns an object with SIOC Information" {
            Get-VMWaredataStoreSIOC -DataStore 'test' | Should beoftype PSCustom
        } -Pending
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Set-VMWareDataStoreSIOC" -Tags Tools {
        
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareHostLog" -Tags DataStore {

    #    Mock -Command Invoke-SSHCommand -Mockwith {
    #        Return ("file.log","text.log")
    #    }

        Context Output {

            IT "Should return a list of files" {
                
            }

        }
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareHostLogList" -Tags DataStore {

  #      Mock -Command Invoke-SSHCommand -Mockwith {
  #          Return "Error Log"
  #      }

        Context Output {

            IT "Should return a text doc" {
                
            }

        }
    }

    #-------------------------------------------------------------------------------------

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareVMLog" -Tags Tools {
        
        $VM = [PSCustomObject]@{
            ExtensionData = [PSCustomObject]@{
                Config = [PSCustomObject]@{
                    Files = [PSCustomObject]@{
                        LogDirectory = '[TestDrive:/]VMName'
                    }
                }
            }
        }


        Mock -CommandName Get-Datacenter -ParameterFilter { $VM } -MockWith {
            $Obj = [PSCustomObject]@{
                Name = 'DC'
            }
            Return $Obj
        }

        Mock -CommandName Get-VM -MockWith {
            $obj = [PSCustomObject]@{
                ExtensionData = [PSCustomObject]@{
                    Config = [PSCustomObject]@{
                        Files = [PSCustomObject]@{
                            LogDirectory = '[TestDrive:/]VMName'
                        }
                    }
                }
            }

            Return $Obj
        }

        Mock -CommandName Get-DataStore -MockWith {
        }

        Mock -CommandName Get-Random -MockWith { Return 7 }

        Mock -CommandName New-PSDrive { }

        Mock -CommandName Copy-DatastoreItem {
            Set-Content -Path 'TestDrive:\log.log' -Value "Test log"
        }

        Mock -CommandName Remove-PSDrive {}

        Context OUtput {
            It 'Should create log files when passed a VM object' {

            }

            It 'SHould create log file when passed a VM Name (String)' {
                
                Get-VMWareVMLog -VM 'VMName' -Path 'TestDrive:\Log.log' 
                TestDrive:\Log.log | Should -Exist
            } -Pending
        } 
    }

   

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Test-VMWareHostConnection" -Tags Tools {
        
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareResourceShare" -Tags Tools {
        
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : CalculateVMWareResourceSharePercentageHelper" -Tags Tools {
        
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Find-VMWareResourceSharePercentage" -Tags Tools {
        
    }

    #-------------------------------------------------------------------------------------

    Write-Output "`n`n"

    Describe "$ModuleName : Get-VMWareRamdisk" -Tags Tools {
        Mock -CommandName Get-ESXCLI -MockWith {
            $RD = [PScustomObject]@{
                System = [PSCustomObject]@{
                    visorfs = [PSCustomObject]@{
                        ramdisk = [PSCustomObject]@{
                            List = [PSCustomObject]@{
                                Invoke = [PSCustomObject]@{
                                    Path = '/tmp'
                                    FreeSpace = 0
                                }
                            }
                        }
                    }
                }
            }

            Return $RD
        }

        $VMHost = New-MockObject -Type VMware.VimAutomation.ViCore.Impl.V1.Inventory.VMHostImpl
    #    $VMHost.Name = 'TestHost'

        Context Output {
            It ' Return a Ramdisk object' {
                Get-VMWareRamdisk -VMHost $VMHost | Should beoftype PSObject
            } -pending
        }
    }
}