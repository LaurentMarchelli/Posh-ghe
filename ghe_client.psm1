#
# ghe_client.psm1 : GheClient Exported Functions
# 

Function Get-GheClient
{
<#
	.SYNOPSIS 
		Get GheClient object to manage the GitHub Enterprise Server

	.DESCRIPTION

	.PARAMETER ServerUri
		Full GitHub Enterprise Server URI, including protocol (http or https)

	.PARAMETER AdminToken
		GitHub Enterprise Administrator token

	.PARAMETER SshKeyPath
		SSH RSA private key path used to connect to GitHub Enterprise server with SSH

	.PARAMETER SshHostPort
		SSH port used to connect to GitHub Enterprise server (default is 122)

	.EXAMPLE

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance. See links.

	.LINK
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/
#>
    [CmdletBinding()]
	[OutputType([GheClient])]

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
