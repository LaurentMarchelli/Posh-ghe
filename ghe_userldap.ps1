#
# ghe_userldap.ps1 : GheLDAPUser Implementation Classes
# 

# LDAP Data Interchange Format
# https://fr.wikipedia.org/wiki/LDAP_Data_Interchange_Format
Class GheLDAPItem
{
	[String]$Name
	[String]$Value
	[Bool]$Base64

	GheLDAPItem(
		[String]$Name,
		[String]$Value,
		[Bool]$Base64)
	{
		$this.Name = $Name
		$this.Value = $Value
		$this.Base64 = $Base64
	}

	GheLDAPItem(
		[String[]]$NameValue,
		[Bool]$Base64)
	{
		$this.Name = $NameValue[0]
		$this.Value = $NameValue[1]
		$this.Base64 = $Base64
	}
}

class GheLDAPRequest : GheCommand
{
	[HashTable]$Ldif

	GheLDAPRequest([String]$Query) : base($Query) 
		{ $this.Ldif = @{} }

	# Virtual callback method used to parse the result
	[void] SetResponse([System.Object]$Response)
	{
		([GheCommand]$this).SetResponse($Response)

		# Extract items from ldif text into a list
		$ldif_txt = $this.Response.Output
		$ldif_res = $this.Ldif
		$ldif_add = New-Object System.Collections.ArrayList
		$ldif_ignore = $true
		ForEach($ldif_line in $ldif_txt)
		{
			switch -regex ($ldif_line)
			{
				"^([a-z]*): (.*)$" # Normal Encoding first line
				{
					$null = $ldif_add.Add([GheLDAPItem]::new($matches[1..2], $false)); 
					$ldif_ignore = $false; break
				}

				"^([a-z]*):: (.*)$" # Base 64 encoding first line
				{
					$null = $ldif_add.Add([GheLDAPItem]::new($matches[1..2], $true)); 
					$ldif_ignore = $false; break
				}

				"^#.*$" # Ignore commented Lines
					{ $ldif_ignore = $true; break }

				"^ *$" # Ignore empty Lines
					{ $ldif_ignore = $true; break }

				default # Add the content to the last value
				{
					if(!$ldif_ignore)
						{ $null = $ldif_add[-1].Value += $ldif_line.Trim() }
				}
			}
		}
		
		# Convert the item list into a hash table
		ForEach($ldif_item in $ldif_add)
		{
			# Convert Base64 characters into UTF8
			if($ldif_item.Base64)
			{
				$ldif_item.Value = [System.Text.Encoding]::UTF8.GetString(
					[System.Convert]::FromBase64String($ldif_item.Value))
			}

			# Add the entry if it does not exist yet
			if(!$ldif_res.ContainsKey($ldif_item.Name))
				{ $null = $ldif_res.Add($ldif_item.Name, $ldif_item.Value) }
			# Otherwise, convert existing value into an array of values
			else
			{
				if($ldif_res[$ldif_item.Name].GetType() -ne @().GetType())
					{ $ldif_res[$ldif_item.Name] = @($ldif_res[$ldif_item.Name]) }
				$ldif_res[$ldif_item.Name] += $ldif_item.Value
			}
		}
	}
}

class GheLDAPUser : GheUser
{
	Hidden [Hashtable] $_ldif

	GheLDAPUser(
		[GheConfig] $config,
		[Hashtable] $ldif,
		[String] $suspended_regex
		) :	base(
			$ldif[$config["ldap.profile.uid"]], 
			$ldif[$config["ldap.profile.mail"]],
			[GheUserStatus]::active
		)
	{
		# Customize specific properties
		if($suspended_regex)
		{
			$dn = $ldif["dn"]
			if($dn.GetType() -eq @().GetType())
				{ $dn = $dn[0] }
			if($dn -match $suspended_regex)
				{ $this.suspension_status = [GheUserStatus]::suspended }
		}

		# Add non specific properties
		$exclude =  $this.psobject.properties.ForEach({$_.Name})
		$ldif.Keys | Where {$_ -notin @("result", "search", "dn", $config["ldap.profile.mail"])}  | 
			Where {$_ -notin $exclude} | % {
			$this | Add-Member NoteProperty -Name $_ -Value $ldif[$_]}

		$this._ldif = $ldif
	}
}

class GheLDAPUserCollection : GheUserCollection
{
	GheLDAPUserCollection([GheClient] $GheClient) : base($GheClient) 
	{
		# Create a Property to save the list of commands (Not a HashTable Key !)
		$CommandList = [GheCommandCollection]::new()
		$this | Add-Member NoteProperty -Name _Command -Value $CommandList
		
		# Get Github LDAP Configuration parameters
		$Config = [GheConfig]::new($GheClient, "^ldap\..*$")
		$this | Add-Member NoteProperty -Name _Config -Value $Config

		# Prepare ldapsearch command line with configuration parameters
		# http://www.openldap.org/software/man.cgi?query=ldapsearch&apropos=0&sektion=0&manpath=OpenLDAP+2.0-Release&format=html
		# H : Specify URI(s) referring to the ldap server(s)
		$CommandText = 'ldapsearch -H "ldap://{0}:{1}"' -f ($Config["ldap.host"], $Config["ldap.port"])
		
		# -x : Use simple authentication instead of SASL.
		# -D : Use the Distinguished Name binddn to bind to the LDAP directory.
		# -w : Use bindpasswd as the password for simple authentication.
		$CommandText += ' -x -D "{0}" -w "{1}"' -f ($Config["ldap.bind-dn"], $Config["ldap.password"])

		# Run ldapsearch group command line
		# -b : Use searchbase as the starting point for the search instead of the default.
		$CommandObj = [GheLDAPRequest]::new(('{0} -b "{1}" "CN={2}" member' -f 
			$CommandText, 
			$Config["ldap.base"],
			$Config["ldap.user-groups"]))
		$GheClient.SendCommand($CommandObj)
				
		# For each group member run ldapsearch user information command line
		# -b : Use searchbase as the starting point for the search instead of the default.
		$CommandText += ' -b "{0}" ' + ('{0} {1} {2}' -f 
			$Config["ldap.profile.uid"],
			$Config["ldap.profile.name"], 
			$Config["ldap.profile.mail"])
		ForEach($ldap_dn in $CommandObj.Ldif["member"])
			{ $CommandList.Add([GheLDAPRequest]::new($CommandText -f $ldap_dn)) }
		$GheClient.SendCommand($CommandList)

		# Create GheLDAPUser objects from LDIF results
		$suspended_regex = $GheClient.ExtParameters["GheLDAPUser.Suspended.Regex"]
		$CommandList.ForEach({
			$user=[GheLDAPUser]::new($Config, $_.Ldif, $suspended_regex)
			$this.Add($user.login, $user)})

		# Insert the Run ldapsearch group command at the top of the command list
		$CommandList.Insert(0,$CommandObj)
	}

	[void] ExportToCsv([String] $ExportFilePath)
	{
		$this.ExportToCsv($ExportFilePath, @("login"), @(
			"login",
			$this._Config["ldap.profile.uid"],
			"email",
			$this._Config["ldap.profile.name"],
			"suspension_status"
			)
		)
	}
}

