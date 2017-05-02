#
# ghe_client.ps1 : GheClient Implementation Classes
# 

#####################################################
#			SSH Command class helpers
#####################################################
class GheCommand
{
	[String]$Query
	[System.Object]$Response

	GheCommand([String]$Query)
		{ $this.Query = $Query }

	# Virtual callback method used to parse the result
	SetResponse([System.Object]$Response)
		{ $this.Response = $Response }
}

class GheCommandCollection : System.Collections.ArrayList 
{
}

#####################################################
#				Mail class helpers
#####################################################
class GheMailMsg : System.Net.Mail.MailMessage
{
	# Default constructor
	GheMailMsg() : base() {}

	# Copy constructors
	GheMailMsg([System.Net.Mail.MailMessage] $Message) : base()
	{
		[GheMailMsg].GetProperties() | % {
			$name = $_.Name
			$value = $Message.psobject.properties[$name].Value
			if($_.CanWrite)
				{ $this.psobject.properties[$name].Value = $value }
			elseif($value.GetType().GetInterface("IList"))
				{ $value.ForEach({$this.psobject.properties[$name].Value.Add($_)}) }
		}
	}
}

class GheMailMsgCollection : System.Collections.Generic.List[System.Net.Mail.MailMessage] 
{
}

#####################################################
#				GheClient class 
#####################################################
class GheClient
{
	# Octokit Connection Support
	[System.Uri]$ServerUri
	[Octokit.ApiConnection]$ApiConnection

	# Octokit overrides
	Hidden [System.Reflection.MethodInfo]$_CreateImpersonationToken

	# Ssh Connection Support
	[String]$SshServerUri
	[UInt16]$SshHostPort
	[String]$SshKeyPath
	[System.Management.Automation.PSCredential]$SshCredentials

	# Extented Parameters
	[Hashtable]$Params

	GheClient(
		[String]$ServerUri,
		[String]$AdminToken,
		[Int32]$SshHostPort,
		[String]$SshKeyPath)
	{
		# Octokit Connection support
		$this.ServerUri = [System.Uri]::new($ServerUri)
		$this.ApiConnection = [GheClient]::GetApiConnection(
			$this.ServerUri, $AdminToken)

		# Overriding UserAdministrationClient.CreateImpersonationToken(...) which does not
		# return the administration token :-(
		$this._CreateImpersonationToken = $this.ApiConnection.GetType().
			GetMethod("Post",  [System.Type[]] @([System.Uri], [System.Object])).
			MakeGenericMethod([System.Collections.Generic.Dictionary[String,Object]])

		# Ssh Connection support
		$this.SshServerUri = $this.ServerUri.Host
		$this.SshHostPort = $SshHostPort
		$this.SshKeyPath = $SshKeyPath
		$this.SshCredentials = [System.Management.Automation.PSCredential]::new(
			“admin”, 
			(ConvertTo-SecureString “admin” -AsPlainText -Force)
		)

		# Extented Parameters
		$this.Params = [Hashtable]::new()
	}

	#####################################################
	#		Octokit Connection implementation
	#####################################################
	static [Octokit.ApiConnection] GetApiConnection(
		[System.Uri] $ServerUri,
		[String] $UserToken)
	{
		return [Octokit.ApiConnection]::new(
			[Octokit.Connection]::new(
				[Octokit.ProductHeaderValue]::new("GheClient"),
				[System.Uri]::new($ServerUri, "/api/v3/"),
				[Octokit.Internal.InMemoryCredentialStore]::new(
					[Octokit.Credentials]::new($UserToken))
			)
		)
	}

	[String] CreateImpersonationToken([string]$Login)
	{
		[System.Object[]] $par_lst = @(
			[Octokit.ApiUrls]::UserAdministrationAuthorization($Login),
			[Octokit.NewImpersonationToken]::new([System.String[]] @("user"))
		)
		$res_val = $this._CreateImpersonationToken.Invoke($this.ApiConnection, $par_lst)
		$res_obj = $res_val.Result
		return $res_obj["token"]
	}

	[void] DeleteImpersonationToken([string]$Login)
	{ 
		$admin = [Octokit.UserAdministrationClient]::new($this.ApiConnection)
		$res_val = $admin.DeleteImpersonationToken($Login)
		$res_val.Result
	}

	#####################################################
	#		Ssh Connection implementation
	#####################################################
	[GheCommand] SendCommand([String]$CommandTxt)
	{
		$Command = [GheCommand]::new($CommandTxt)
		$this.SendCommand($Command)
		return $Command
	}

	Hidden [GheCommand] SendCommand([GheCommand]$CommandObj)
	{
		$CommandList = [GheCommandCollection]::new()
		$CommandList.Add($CommandObj)
		return $this.SendCommand($CommandList)[0]
	}

	Hidden [GheCommandCollection] SendCommand([GheCommandCollection]$CommandList)
	{
		# Open SSH session
		$srv_ses = $null
		$srv_wrn = $null
		$srv_err = $null
		try
		{
			$srv_ses = New-SSHSession `
				-ComputerName $this.SshServerUri `
				-Port $this.SshHostPort `
				-KeyFile $this.SshKeyPath `
				-Credential $this.SshCredentials `
				-AcceptKey -Force `
				-WarningVariable $srv_wrn `
				-WarningAction SilentlyContinue `
				-ErrorVariable $srv_err `
				-ErrorAction Stop
		}
		catch
		{
			throw $srv_err
		}
		# Run all Commands in the list
		ForEach($srv_cmd in $CommandList)
		{
			$srv_res = Invoke-SSHCommand -Index $srv_ses.SessionId -Command $srv_cmd.Query
			$srv_cmd.SetResponse($srv_res)
		}
		# Close SSH session
		Remove-SSHSession $srv_ses
		return $CommandList
	}

	# Remove the Announce Message
	[GheCommand] ClearAnnounce()
		{ return $this.SendAnnounce($null) }
	
	# Set or Remove the Announce Message
	[GheCommand] SendAnnounce([String]$Message)
	{ 
		# Usage: ghe-announce [-s <message>|-u]
		#
		# Set or clear a global announcement banner, to be displayed to all users.
		#
		# OPTIONS:
		#   -h            Show this message
		#   -s MESSAGE    Set a global announcement banner
		#   -u            Unset the global announcement banner
		
		# Linux command to display announce
		if($Message)
			{ $CommandTxt = ('ghe-announce -s "{0}"' -f $Message) }
		# Linux command to remove existing announce
		else
			{ $CommandTxt = 'ghe-announce -u' }

		# Run ssh command to get the result
		return $this.SendCommand($CommandTxt)
	}

	# Mail helpers
	[GheCommand] SendMail(
		[System.Net.Mail.MailMessage] $EmailObj)
	{
		$EmailList = [GheMailMsgCollection]::new()
		$EmailList.Add($EmailObj)
		return $this.SendMail($EmailList)[0]
	}

	[GheCommandCollection] SendMail(
		[System.Collections.Generic.List[System.Net.Mail.MailMessage]] $EmailList
	)
	{
		$CommandList = [GheCommandCollection]::new()
		ForEach($Email in $EmailList)
		{
			if($Email.From) { $msg_txt = "From: $($Email.From)`n" }
			else { $msg_txt = "From: $($Email.Sender)`n" }
			
			$Email.psobject.Properties | Where { $_.Name -in @("To", "Cc", "Bcc") } |
				ForEach-Object { $msg_txt += "{0}: {1}`n" -f $_.Name, ($_.Value -join ",") }
			$msg_txt += "Subject : {0}`n{1}`n." -f
				$Email.Subject.Replace("\","\\").Replace("`"","\`""),
				$Email.Body.Replace("\","\\").Replace("`"","\`"")
			
			$msg_cmd = "echo `"$msg_txt`" | sendmail -t /USER $($Email.Sender)"
			$CommandList.Add([GheCommand]::new($msg_cmd))
		}
		if($CommandList.Count)
			{ $this.SendCommand($CommandList) }
		return $CommandList
	}

	# User Helpers
	[GheCommand] UserSuspend([String] $login)
		{ return $this.SendCommand("ghe-user-suspend {0}" -f $login) }

	[GheCommand] UserUnsuspend([String] $login)
		{ return $this.SendCommand("ghe-user-suspend {0}" -f $login) }

	[GheCommand] UserPromote([String] $login)
		{ return $this.SendCommand("ghe-user-promote {0}" -f $login) }

	[GheCommand] UserDemote([String] $login)
		{ return $this.SendCommand("ghe-user-demote {0}" -f $login) }
}

