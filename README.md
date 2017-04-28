# Posh-ghe
Powershell Module for GitHub Entreprise Administration

## Description
The Posh-ghe Powershell package aim is to help Github Enterprise Server administration and management.<br>
It uses [Posh-SSH](https://github.com/darkoperator/Posh-SSH) to be able to run linux commands remotely and the [Octokit.net](https://github.com/octokit/octokit.net) binary to be able to use the GitHub Server api with HTTP requests.

It allows you to :

- Send a ssh command on the GitHub Enterprise Server and get the result.
- Display / clear an announce message on the GitHub Enterprise Server.
- Suspend / unsuspend a user.
- Promote / demote a user.
- Send a mail using the GitHub Enterprise email client configuration.
- Get GitHub Enterprise configuration parameters
- Get GitHub Enterprise users directory.
- Get LDAP users directory.
- Synchronize GitHub users with LDAP directory.
- Get repository branches.
- Synchronize repository branches.

## How to install

1. If you are running Windows 7.0, install [Powershell 5.0](https://www.microsoft.com/en-us/download/details.aspx?id=50395)

1. From Windows Command Line, install [Posh-SSH](https://github.com/darkoperator/Posh-SSH):<br>
``powershell -executionpolicy Bypass -command "Find-Module PoSH-SSH | Install-Module"``

1. Clone this repository<br>
``git clone https://github.com/diagnostica-stago/Posh-ghe.git C:\Temp\Posh-ghe``

1. From Powershell, import the module<br>
``Import-Module C:\Temp\Posh-ghe.psd1``

1. Have a look to [Tests](tree/master/Tests) subdirectory to have an usage overview.

1. Have a look to the [Wiki](https://github.com/diagnostica-stago/Posh-ghe/wiki) for further information.

## ChangeLog
### Version 0.1.1
- Initial public version
- [Octokit.net v.0.21.1](https://github.com/octokit/octokit.net/releases/tag/v0.21.1)
- [Posh-SSH v1.7.7 or higher](https://github.com/darkoperator/Posh-SSH/releases)

## Licenses
### Posh-ghe
<i>GNU General Public License v3.0</i><br>
https://github.com/diagnostica-stago/Posh-ghe/blob/master/LICENSE

### Octokit.net
<i>MIT License</i><br>
https://github.com/octokit/octokit.net/blob/master/LICENSE.txt

### Posh-SSH
<i>BSD 3-clause "New" or "Revised" License</i><br>
https://github.com/darkoperator/Posh-SSH/blob/master/License.md

