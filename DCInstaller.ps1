# Force script execution policy bypass
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force

# Disable UAC
New-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA -PropertyType DWord -Value 0 -Force

# Execution state flag
$state = $1
if($state -eq $null) { $state = 0 }
Write-host " Execution State Detected: $state" 

# Paths setup
$drive = Get-Volume | Where-Object { $_.FileSystemLabel -like "DCINSTA" }
$drvpath = $drive.DriveLetter + ":\"
$script = "DCInstaller.ps1"
$filepath = $drvpath + $script
$folder = "Config\"
$file_conf = "BaseData.csv"
$filepath_conf = $drvpath + $folder + $file_conf

# Load configuration data from CSV
if($state -eq 0){
    $excel = Import-Csv -Delimiter ";" -Path $filepath_conf -Header NomeHost, IpAddress, Netmask, Gateway, DnsServer, SystemLocale, TimeZone, Keyboard, ProductKey
}
else{
    $excel = Import-Csv -Delimiter ";" -Path "C:\PS\Config\BaseData.csv" -Header NomeHost, IpAddress, Netmask, Gateway, DnsServer, SystemLocale, TimeZone, Keyboard, ProductKey
}

# Initialize variables
$netadapters = Get-NetAdapter
$HostName = $excel.NomeHost[1]
$IpAddress = $excel.IpAddress[1]
$Netmask = $excel.Netmask[1]
$Gateway = $excel.Gateway[1]
$DnsServer = $excel.DnsServer[1]
$SystemLocale = $excel.SystemLocale[1]
$TimeZone = $excel.TimeZone[1]
$Keyboard = $excel.Keyboard[1]
$ProductKey = $excel.ProductKey[1]

######################################################################################################################
# Functions

# Check for pending reboot status
function Test-PendingReboot {
 if (Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -EA Ignore) { return $true }
 if (Get-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -EA Ignore) { return $true }
 if (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -EA Ignore) { return $true }
 try { 
   $util = [wmiclass]"\\.\root\ccm\clientsdk:CCM_ClientUtilities"
   $status = $util.DetermineIfRebootPending()
   if(($status -ne $null) -and $status.RebootPending){
     return $true
   }
 }catch{}
 return $false
}
write-host "Test-PendingReboot function initialized"

# Create a scheduled task to run at startup
Function Set-RebootTask {
    $Trigger= New-ScheduledTaskTrigger -AtStartup
    $User= "NT AUTHORITY\SYSTEM"
    $Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\DCInstaller.ps1 $state"
    Register-ScheduledTask -TaskName "Reboot-Task" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest -Force
}
write-host "Set-RebootTask function initialized"

# Install script to local path
$find = dir c:\ | Select-Object -Property Name | where {$_.Name -eq "ps"}
if($find -eq $null){
    mkdir C:\PS\
    mkdir C:\PS\Config
    cat -Path $filepath | Out-File -FilePath "C:\PS\DCInstaller.ps1"
    cat -Path $filepath_conf | Out-File -FilePath "C:\PS\Config\BaseData.csv"
    Start-Transcript C:\PS\LogFile.txt 
    Write-host "State $state : Script installation completed!"
    $state++
} else {
    $state++ 
}
Write-host "State 0: Script installation completed!"

while($state -lt 7){
    switch($state){
        1 {
            # Network configuration
            Write-Host "Network Configuration"
            New-NetIPAddress –IPAddress $IpAddress -DefaultGateway $Gateway -PrefixLength $Netmask -InterfaceIndex (Get-NetAdapter).InterfaceIndex
            Set-DNSClientServerAddress –InterfaceIndex (Get-NetAdapter).InterfaceIndex –ServerAddresses $DnsServer
            
            # Disable network adapters
            Write-host "Disabling network adapter"
            ForEach($adapt in $netadapters){ 
                if ($adapt.Status -eq "Enabled"){
                    Write-Host "Disabling $($adapt.name)" 
                    Disable-NetAdapter -name $adapt.Name
                    sleep 3
                }
            }

            # Enable network adapters
            Write-host "Re-enabling network adapter"
            ForEach($adapt in $netadapters){
                if ($adapt.Status -eq "Disabled"){
                    Enable-NetAdapter -name $adapt.Name
                    sleep 3
                }
            }
            $state++
            Write-host "State $state : Network configuration completed"
        }

        2 {
            # Localization settings
            write-host "Setting System Locale"
            Set-WinSystemLocale -SystemLocale $SystemLocale
            Set-Culture $SystemLocale 
            Set-TimeZone -Id $TimeZone 
            Set-WinUserLanguageList -LanguageList $Keyboard -Force
            $state++
            Write-host "State $state : Locale configuration completed" 
        }

        3 {
            # Windows Activation
            write-host "Activating Windows"
            $KMSservice = Get-WMIObject -query "select * from SoftwareLicensingService"
            Write-Debug 'Activating Windows.'
            $null = $KMSservice.InstallProductKey($ProductKey)
            $null = $KMSservice.RefreshLicenseStatus()
            $state++
            Write-host "State $state : Windows activation completed" 
        }

        4 {
            # Install required modules
            write-host "Installing WindowsUpdate module"
            $PSVersionTable.PSVersion
            Install-Module PSWindowsUpdate -Force
            Get-Command -module PSWindowsUpdate
            Write-host "Registering update service"
            Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -confirm:$false
            Write-host "State $state : Module installation completed" 
            $state++
        }

        5 {
            # Set reboot task and install updates
            Set-RebootTask
            Write-host "State $state a: Scheduled reboot task created" 
            Get-WUList -MicrosoftUpdate
            Get-WUInstall -MicrosoftUpdate -AcceptAll -Download -Install
            If(Test-PendingReboot){
                Restart-Computer -Force
            }
            Write-host "State $state b: Updates installed" 
            $state++
        }

        6 {
            # Hostname change
            if($Hostname -ne $env:COMPUTERNAME){
                Set-RebootTask
                $state++
                Rename-computer –newname $Hostname –force
                Restart-Computer -Force
            } else {
                $state++
            }
        }

        default {
            Write-host "Error.... Error everywhere!!!"
        }
    }
}

# Re-enable UAC
New-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA -PropertyType DWord -Value 1 -Force
Write-host "State 6: Hostname modified" 
Stop-Transcript
c:\PS\LogFile.txt
