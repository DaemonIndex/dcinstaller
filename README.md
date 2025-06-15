# DCInstaller

## Description

PowerShell script for the automatic configuration of Windows server in a corporate environment. It automates network settings, system localization, Windows activation, update installation, and hostname changes.

## Main Features

- Configuration of IP address, gateway, DNS

- Localization and timezone settings

- Windows activation via Product Key

- Automatic installation of system updates

- Scheduled task management for automatic reboot

- Hostname change with reboot

## How to Use

- Clone the repository

- Copy `BaseData.csv` into the `Config` folder with your custom parameters

- Run `DCInstaller.ps1` with administrative privileges

- The script will execute the steps in sequence, rebooting the machine if necessary

## Requirements

- PowerShell 5.1 or higher

- Administrator privileges

- Supported Windows 2008R2

## Notes

The CSV file must be formatted with the following fields: `NomeHost`, `IpAddress`, `Netmask`, `Gateway`, `DnsServer`, `SystemLocale`, `TimeZone`, `Keyboard`, `ProductKey`, separated by `;`

## License

This project is licensed under the [GNU GPL v3.0](LICENSE).

--- 

> 🇮🇹 Leggi questo README in italiano: [README.it.md](README.it.md)
