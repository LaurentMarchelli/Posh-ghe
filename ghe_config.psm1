#
# ghe_config.psm1 : GheConfig Exported Functions
# 

Function Get-GheConfig
{
<#
	.SYNOPSIS 
		Get GitHub Enterprise Server's configuration.

	.DESCRIPTION
		The returned object is a Dictionnary containing part or all GitHub Enterprise
		Server configuration parameters.
		The Filter parameter is a RegEx string allowing to reduce the scope of requested 
		configuration.

	.PARAMETER ServerUri
		Full GitHub Enterprise Server URI, including protocol (http or https)

	.PARAMETER AdminToken
		GitHub Enterprise Administrator token

	.PARAMETER SshKeyPath
		SSH RSA private key path used to connect to GitHub Enterprise server with SSH

	.PARAMETER SshHostPort
		SSH port used to connect to GitHub Enterprise server (default is 122)

	.PARAMETER GheClient
		GheClient object previously created with Get-GheClient (pipeline value)

	.PARAMETER Filter
		Expression used to limit the configuration result keys to RegEx evaluation.

	.OUTPUTS
		[GheConfig]

	.EXAMPLE
		# Return the full GitHub Enterprise Configuration
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		Get-GheConfig @Params

	.EXAMPLE
		# Return configuration for smtp, ldap and core
		$Params = @{
			ServerUri =  "http://github.mycompany.com/"
			AdminToken = "636e3227468e4e09f397e3ecb26860eed9fbeaff"
			SshKeyPath = join-path $env:HOMEPATH ".ssh/github.mycompany.com_rsa"
		}
		Get-GheClient @Params | Get-GheConfig -Filter "^(smtp|ldap|core)\..*$"

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance.
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/

	.LINK
		Get-GheClient
#>
    [CmdletBinding()]

	Param(
		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $ServerUri,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $AdminToken,

		[Parameter(Mandatory=$true, ParameterSetName = "Connect")]
		[ValidateNotNullOrEmpty()]
		[String] $SshKeyPath,
		
		[Parameter(Mandatory=$false, ParameterSetName = "Connect")]
		[UInt16] $SshHostPort = 122,

		[Parameter(Mandatory=$true, ParameterSetName = "Session", ValueFromPipeline=$true)]
		[ValidateNotNullOrEmpty()]
		[GheClient] $GheClient,

		[Parameter(Mandatory=$false)]
		[String] $Filter
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
		if ($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		return [GheConfig]::new($GheClient, $Filter)
	}
	End
	{
		Write-Verbose "$($MyInvocation.MyCommand.Name):: Function ended"
	}
}
