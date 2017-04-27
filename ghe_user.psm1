#
# ghe_user.psm1 : GheClient Exported Functions
# 

Function Get-GheGHubUsers
{
<#
	.SYNOPSIS 
		Get GitHub Enterprise Server's user list

	.DESCRIPTION

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

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the GitHub's user list.
    
	.EXAMPLE

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance. See links.

	.LINK
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/
#>
    [CmdletBinding()]
	[OutputType([GheGHubUserCollection])]

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
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile
	)
	Begin {}
	Process 
	{
		if ($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		$GheGHubUsers = [GheGHubUserCollection]::new($GheClient)

		if($CsvExportFile)
			{ $GheGHubUsers.ExportToCsv($CsvExportFile) }

		return $GheGHubUsers
	}
	End {}
}

Function Get-GheLDAPUsers
{
<#
	.SYNOPSIS 
		Get LDAP's user list used by GitHub Enterprise Server to allow server access.

	.DESCRIPTION
		The function uses the GitHub Enterprise configuration and the ssh connection to run the 
		required LDAP query.

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

	.PARAMETER SuspendedRegEx
		RegEx used to check against LDAP DN if the user is Suspended.

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the LDAP's user list.
    
	.EXAMPLE

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance. See links.

		SuspendedRegEx can be inclusive or exclusive, for instance :
			# When suspended users are removed from the LDAP group named "users"
			$SuspendedRegEx = "^(?!.*OU=users).*$"
			# When suspended users are added to LDAP group named "disabled"
			$SuspendedRegEx = "^.*OU=disabled.*$"

	.LINK
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/
#>
    [CmdletBinding()]
	[OutputType([GheLDAPUserCollection])]

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
		[ValidateNotNullOrEmpty()]
		[String] $SuspendedRegEx,

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile

	)
	Begin {}
	Process 
	{
		if($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		if($SuspendedRegEx)
			{ $GheClient.ExtParameters["GheLDAPUser.Suspended.Regex"] = $SuspendedRegEx }

		$GheLDAPUsers = [GheLDAPUserCollection]::new($GheClient)
		if($GheLDAPUsers.Values.Count -eq 0)
			{ Write-Error "GheLDAPUserCollection is empty, check your LDAP configuration into your GitHub instance`r`n" }

		if($CsvExportFile)
			{ $GheLDAPUsers.ExportToCsv($CsvExportFile) }

		return $GheLDAPUsers
	}
	End {}
}

Function Sync-GheLDAPUsers
{
<#
	.SYNOPSIS 
		Synchronize GitHub's user list with LDAP's user list

	.DESCRIPTION
		The function synchronize a GitHub Enterprise's user list when your server is configured 
		to use LDAP authentication, but not the LDAP synchronization.

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
    
	.PARAMETER SuspendedRegEx
		RegEx used to check against LDAP DN if the user is Suspended.

	.PARAMETER UsersIgnored
		List of GitHub local user's login who must be ignored during the comparaison and the synchronization.

	.PARAMETER CsvExportFile
		Full file path of the comma separated file used to export the comparison between the
		GitHub's user list and the LDAP's user list after the synchronization is done.

	.EXAMPLE

	.NOTES
		Before using this script, create a SSH key and upload it onto GitHub instance. See links.

		The function compares both list and analyses differences, if a synchronization is needed, 
		it will try to synchronize user status and create new users :
		- User not found in LDAP are suspended in GitHub.
		- User found in LDAP is created in GitHub, if he does not already exist.
		- User found in LDAP are actived in GitHub, if he already exists.
		When the synchronization is done, the function runs a final analysis.
		All results messages are sent to the output.

		SuspendedRegEx can be inclusive or exclusive, for instance :
			# When suspended users are removed from the LDAP group named "users"
			$SuspendedRegEx = "^(?!.*OU=users).*$"
			# When suspended users are added to LDAP group named "disabled"
			$SuspendedRegEx = "^.*OU=disabled.*$"

	.LINK
		https://help.github.com/enterprise/admin/guides/user-management/using-ldap/
		https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
		https://help.github.com/enterprise/admin/guides/installation/administrative-shell-ssh-access/
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
		[ValidateNotNullOrEmpty()]
		[String] $SuspendedRegEx,

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String[]] $UsersIgnored,

		[Parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[String] $CsvExportFile
	)
	begin
	{
		Function DumpAnalysis(
			[HashTable] $GheAnalysis,
			[String] $Title)
		{
			# Print Analysis Results
			if(!$PSCmdlet.MyInvocation.BoundParameters["Verbose"]) { return }

			$output_txt = "{0} Information" -f $Title
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			$GheAnalysis["Ignored"] | % {
				Write-Verbose ("[IGNORED] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
			$GheAnalysis["ToEnabled"] | % {
				Write-Verbose ("[TO ENABLE] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
			$GheAnalysis["ToDisable"] | % {
				Write-Verbose ("[TO DISABLE] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
			$GheAnalysis["ToCreate"] | % {
				Write-Verbose ("[TO CREATE] {0} ({1}) {2}" -f $_.trg_login, $_.trg_email, $_.trg_suspension_status) }

			$output_txt = "{0} Results" -f $Title
			Write-Verbose ("#" * 100)
			Write-Verbose $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
			Write-Verbose ("#" * 100)
			Write-Verbose ("[STATUS] {0:N0} Ignored (Local GitHub users)" -f $GheAnalysis["Ignored"].Count)
			Write-Verbose ("[STATUS] {0:N0} Enabled" -f $GheAnalysis["Enabled"].Count)
			Write-Verbose ("[STATUS] {0:N0} Disabled" -f $GheAnalysis["Disabled"].Count)
			Write-Verbose ("[STATUS] {0:N0} should be Enabled" -f $GheAnalysis["ToEnabled"].Count)
			Write-Verbose ("[STATUS] {0:N0} should be Disabled" -f $GheAnalysis["ToDisable"].Count)
			Write-Verbose ("[STATUS] {0:N0} should be Created" -f $GheAnalysis["ToCreate"].Count)
			Write-Verbose ("-" * 40)
			Write-Verbose ("[STATUS] {0:N0} Total" -f (
				$GheAnalysis["Ignored"].Count +
				$GheAnalysis["Enabled"].Count +
				$GheAnalysis["Disabled"].Count +
				$GheAnalysis["ToEnabled"].Count +
				$GheAnalysis["ToDisable"].Count +
				$GheAnalysis["ToCreate"].Count))
			Write-Verbose ("[STATUS] {0:N0} Evaluated Users" -f $GheCompare.Values.Count)
		}
	}
	process
	{
		if ($PSCmdlet.ParameterSetName -eq "Connect")
			{ $GheClient = [GheClient]::new($ServerUri, $AdminToken, $SshHostPort, $SshKeyPath)	}

		if($SuspendedRegEx)
			{ $GheClient.ExtParameters["GheLDAPUser.Suspended.Regex"] = $SuspendedRegEx }

		# Get LDAP user list
		$GheLDAPColl = [GheLDAPUserCollection]::new($GheClient)
		if($GheLDAPColl.Values.Count -eq 0)
			{ Write-Error "GheLDAPUserCollection is empty, check your LDAP configuration into your GitHub instance`r`n" }

		# Compare Github user list against LDAP user list
		$GheGHubColl = [GheGHubUserCollection]::new($GheClient)
		$GheCompare = [GheUserCompare]::new($GheGHubColl, $GheLDAPColl)

		# Do an initial analysis and dump the Result
		$GheAnalysis = $GheCompare.Analyse($UsersIgnored)
		DumpAnalysis $GheAnalysis "Initial Analysis"

		$err_cnt = 
			$GheAnalysis["ToEnabled"].Count + $GheAnalysis["ToDisable"].Count + 
			$GheAnalysis["ToCreate"].Count
	
		# Synchronize and dump Synchronization Errors
		if($err_cnt -gt 0)
		{
			$GheSynch = $GheCompare.Synch($GheAnalysis, $true)
			$err_cnt = 
				$GheSynch["Enable"].Count + $GheSynch["Disable"].Count +
				$GheSynch["Create"].Count + $GheSynch["SuspendNew"].Count

			if($err_cnt -gt 0)
			{
				$output_txt = "Synchronization Warnings"
				Write-Warning ("#" * 100)
				Write-Warning $output_txt.PadLeft((100 + $output_txt.Length) / 2, " ")
				Write-Warning ("#" * 100)
				$GheSynch["Enable"] | % {
					Write-Warning ("[NOT ENABLED] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
				$GheSynch["Disable"] | % {
					Write-Warning ("[NOT DISABLED] {0} ({1}) {2}" -f $_.login, $_.email, $_.suspension_status) }
				$GheSynch["Create"] | % {
					Write-Warning ("[NOT CREATED] {0} ({1}) {2}" -f $_.trg_login, $_.trg_email, $_.trg_suspension_status) }
				$GheSynch["SuspendNew"] | % {
					Write-Warning ("[BAD CREATION] {0} ({1}) {2}" -f $_.trg_login, $_.trg_email, $_.trg_suspension_status) }
			}

			# Do an final analysis and dump the Result
			$GheAnalysis = $GheCompare.Analyse($UsersIgnored)
			DumpAnalysis $GheAnalysis "Final Analysis"
		}

		# Export Comparison Results
		$GheCompare.ExportToCsv($CsvExportFile)
	}
}

