#Forzo disabilita delle restrizione sugli script
Set-ExecutionPolicy -ExecutionPolicy Bypass -Force
#disabilito UAC
New-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA -PropertyType DWord -Value 0 -Force

#Flag d'esecuzione
$state = $1
if($state -eq $null) { $state = 0 }
Write-host " Controllo Stato Acquisito: $state" 

#Creazione dei percorsi
$drive = Get-Volume | Where-Object { $_.FileSystemLabel -like "DCINSTA" }
$drvpath = $drive.DriveLetter + ":\"
$script = "DCInstaller.ps1"
$filepath = $drvpath + $script
$folder = "Config\"
$file_conf = "BaseData.csv"
$filepath_conf = $drvpath + $folder + $file_conf
 
#Recupero dei dati
if($state -eq 0){
    $excel = Import-Csv -Delimiter ";" -Path $filepath_conf -Header NomeHost, IpAddress, Netmask, Gateway, DnsServer, SystemLocale, TimeZone, Keyboard, ProductKey
}
else{
    $excel = Import-Csv -Delimiter ";" -Path "C:\PS\Config\BaseData.csv" -Header NomeHost, IpAddress, Netmask, Gateway, DnsServer, SystemLocale, TimeZone, Keyboard, ProductKey
}

#Inizializzazione delle variabili
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
#Inizializzazione delle funzioni

#Funzione per la verifica della necessità di riavvio
function Test-PendingReboot
{
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
write-host "Funzione Test-PendingReboot inizializzata"

#funzione per la creazione di una task all'avvio
Function Set-RebootTask
{
    $Trigger= New-ScheduledTaskTrigger -AtStartup # Specify the trigger settings
    $User= "NT AUTHORITY\SYSTEM" # Specify the account to run the script
    $Action= New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "C:\PS\DCInstaller.ps1 $state" # Specify what program to run and with its parameters
    Register-ScheduledTask -TaskName "Reboot-Task" -Trigger $Trigger -User $User -Action $Action -RunLevel Highest –Force # Specify the name of the task
}
write-host "Funzione Set-RebootTask inizializzata"

#installazione dello script in c:\
$find = dir c:\ | Select-Object -Property Name | where {$_.Name -eq "ps"}
if($find -eq $null){
    mkdir C:\PS\
    mkdir C:\PS\Config
    cat -Path $filepath | Out-File -FilePath "C:\PS\DCInstaller.ps1"
    cat -Path $filepath_conf | Out-File -FilePath "C:\PS\Config\BaseData.csv"
    Start-Transcript C:\PS\LogFile.txt 
    Write-host "Stato $state : Installazione dello script eseguito!"
    $state++
}
else{
    $state++ 
}
Write-host "Stato 0: Installazione dello script eseguito!"

while($state -lt 7){
    switch($state){
        1{
            #Configurazione scheda di rete
            Write-Host "Configurazione Network"
            New-NetIPAddress –IPAddress $IpAddress -DefaultGateway $Gateway -PrefixLength $Netmask -InterfaceIndex (Get-NetAdapter).InterfaceIndex
            Set-DNSClientServerAddress –InterfaceIndex (Get-NetAdapter).InterfaceIndex –ServerAddresses $DnsServer
            Write-host "disabilito scheda di rete"
            ForEach($adapt in $netadapters){ 
                if ($adapt.Status -eq "Enabled"){
                Write-Host "Disabilito $(($adapt.name))" 
                Disable-NetAdapter -name $adapt.Name
                sleep 3
                }
            }
            
            Write-host "riabilito scheda di rete"
            ForEach($adapt in $netadapters){
                if ($adapt.Status -eq "Disabled"){
                    Enable-NetAdapter -name $adapt.Name
                    sleep 3
                }
            }
            
            $state++
            Write-host "Stato $state : Configurazione Scheda di rete completata"
        }

        2{
            #Configurazione Systemlocale
            write-host "Configurazione SystemLocale"
            Set-WinSystemLocale -SystemLocale $SystemLocale
            Set-Culture $SystemLocale 
            Set-TimeZone -Id $TimeZone 
            Set-WinUserLanguageList -LanguageList $Keyboard -Force
            #modifico orologio
            #$date = Get-Date
            #set-date = $date.AddHours(1) 
            $state++
            Write-host "Stato $state : Configurazione System locale completata" 

        }

        3{
            #Attivazione di windows
            write-host "Attivazione di windows"
            $KMSservice = Get-WMIObject -query "select * from SoftwareLicensingService"
            Write-Debug 'Activating Windows.'
            $null = $KMSservice.InstallProductKey($ProductKey)
            $null = $KMSservice.RefreshLicenseStatus()
            $state++
            Write-host "Stato $state : Attivazione di Windows completata" 

        }

        4{
            #Installazione moduli necessari per lo script
            write-host "Installazione Modulo WindowsUpdate"
            $PSVersionTable.PSVersion
            Install-Module PSWindowsUpdate -Force
            Get-Command -module PSWindowsUpdate
            Write-host "Registrazione al Servizio"
            Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -confirm:$false
            Write-host "Stato $state : Installazione moduli eseguita" 

            $state++
        }
        5{
            #imposto task per riavvio
            Set-RebootTask
            Write-host "Stato $state a: Creato Schedule per esecuzione script al riavvio" 
            #installazione aggiornamenti
            Get-WUList -MicrosoftUpdate
            Get-WUInstall -MicrosoftUpdate -AcceptAll -Download -Install
            If(Test-PendingReboot){
                Restart-Computer -Force
            }
            Write-host "Stato $state b: Aggiornamenti installati" 

            $state++
        }

        6{
            #Modifica Hostname
            if($Hostname -ne $envCOMPUTERNAME){
                Set-RebootTask
                $state++
                Rename-computer –newname $Hostname –force
                Restart-Computer -Force
            }
            else{
                $state++
            }
        }
        default{
            Write-host "Error.... Error everywhere!!!"
        }
    }
}
#riabilito UAC
New-ItemProperty -Path HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System -name EnableLUA -PropertyType DWord -Value 1 -Force
Write-host "Stato 6: Modificato Hostname" 
Stop-Transcript
c:\PS\LogFile.txt