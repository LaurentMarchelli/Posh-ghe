#
# ghe_client.psm1 : GheClient Exported Functions
# 

Function Get-GheClient
{
<#
	.SYNOPSIS 
		Get a GheClient object to manage the GitHub Enterprise Server

	.DESCRIPTION
		The GheClient is the connection object allowing GitHub Enterprise appliance management.
		To ensure management security, it works with a ssh key and GitHub administrator token.
		GheClient create both connection, a ssh connection to be able to run remote apliance shell
		commands and an Octokit connection to be able to run GitHub Api commands.

		With a GheClient object itself you can :
		- Create / delete an Octokit impersonation token
		- Get an Octokit api connection for a specific user token
		- Send a ssh command
		- Display an announce message
		- Clear the announce message
		- Suspend a user
		- Unsuspend a user
		- Promote a user
		- Demote a user
		- Send a mail

		GheClient object can also be used as a parameter for others functions (see LINK).

	.PARAMETER ServerUri
		Full GitHub Enterprise Server URI, including protocol (http or https)

	.PARAMETER AdminToken
		GitHub Enterprise Administrator token

	.PARAMETER SshKeyPath
		SSH RSA private key path used to connect to GitHub Enterprise server with SSH

	.PARAMETER SshHostPort
		SSH port used to connect to GitHub Enterprise server (default is 122)

	.OUTPUTS
		[GheClient]

	.EXAMPLE
		# How set an Announce Banner Message on your test server
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_cmd = $ghe_client.SendAnnounce(
			"<h2>WARNING !!!! YOU ARE WORKING ON THE TEST SERVER !!!!</h2>" +
			"(All work done will be deleted by next restoration).")

	.EXAMPLE
		# How to suspend a user
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$ghe_cmd = $ghe_client.UserSuspend("userlogin")

	.EXAMPLE
		# How to send a mail using GitHub email configuration
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		$ghe_client = Get-GheClient @Params
		$email = [System.Net.Mail.MailMessage]::new()
		$email.Sender = [System.Net.Mail.MailAddress]::new("from.user@mycompany.com")
		$email.To.Add([System.Net.Mail.MailAddress]::new("adressee1.user@mycompany.com"))
		$email.To.Add([System.Net.Mail.MailAddress]::new("adressee2.user@mycompany.com"))
		$email.Cc.Add([System.Net.Mail.MailAddress]::new("adressee3.user@mycompany.com"))
		$email.Bcc.Add([System.Net.Mail.MailAddress]::new("adressee4.user@mycompany.com"))
		$email.Subject = "My Email Subject"
		$email.Body = "My Email Body"
		$ghe_cmd = $ghe_client.SendMail($email)

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheConfig
		Get-GheUsers
		Get-GheLDAPUsers
		Get-GheBranches

#>
    [CmdletBinding()]

	Param(
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String] $ServerUri,
		
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String] $AdminToken,

		[Parameter(Mandatory=$false)]
		[UInt16] $SshHostPort=122,
		
		[Parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[String] $SshKeyPath
	)
	Begin
	{
		Write-Debug "PsBoundParameters:"
		$PSBoundParameters.GetEnumerator() | % { Write-Debug $_ }

		if($PSBoundParameters['Debug']) { $DebugPreference = 'Continue' }
		Write-Debug "DebugPreference: $DebugPreference"

		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function started"
	}
	Process 
	{
		return [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}
