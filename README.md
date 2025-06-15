# DCInstaller

## Descrizione

Script PowerShell per la configurazione automatica di workstation Windows in ambiente aziendale. Automatizza impostazioni di rete, sistema, attivazione Windows, installazione aggiornamenti e cambio hostname.

## Funzionalità principali

- Configurazione indirizzo IP, gateway, DNS

- Impostazioni di localizzazione e timezone

- Attivazione Windows tramite Product Key

- Installazione automatica degli aggiornamenti di sistema

- Gestione task programmati per riavvio automatico

- Cambio hostname con riavvio

## Come usare
- Clona il repository

- Copia BaseData.csv nella cartella Config con i parametri personalizzati

- Esegui lo script DCInstaller.ps1 con privilegi amministrativi

- Lo script eseguirà i vari step in sequenza, riavviando la macchina se necessario

## Requisiti
- PowerShell 5.1 o superiore

- Permessi di amministratore

- Windows 10/Server (versioni supportate)

## Note
Il file CSV deve essere formattato con i campi: NomeHost, IpAddress, Netmask, Gateway, DnsServer, SystemLocale, TimeZone, Keyboard, ProductKey, separati da ;
