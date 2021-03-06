Param( 
    [Parameter(Position=0)]
    [string]$Office365Username,
    [Parameter(Position=1)]
    [string]$Office365Password, 
    [Parameter(Position=2)]
    [string]$TeamsFilePath
)

Write-Verbose "Importing modules"
$Module = Get-Module -Name MicrosoftTeams -ListAvailable 
if($Module.Count -eq 0) {   
  Write-Verbose "Installing MicrosoftTeams module"
  Install-Module -Name MicrosoftTeams -AllowPrerelease -AllowClobber -Force
}

# Functions
Function New-MicrosoftTeam([object]$Team) {
  Try {
    Write-Verbose "Creating $($Team.DisplayName) $($Team.Visibility) team"
    $NewTeam = New-Team -DisplayName $Team.DisplayName -Visibility $Team.Visibility
    Write-Verbose "Adding $($Team.Users.Length) users to $($Team.DisplayName) team"
    $Team.Users | ForEach-Object -Begin {
      $Index = 0   
    } -Process {
      $Index = $Index + 1
      Write-Progress -Id 1 -ParentId 0 -Activity "Add user to the team" -Status "$($Index) of $($Team.Users.Length) - User: $($_.Email), Role: $($_.Role)" -PercentComplete ($Index/$Team.Users.Length*100)
      Write-Verbose "Adding $($_.Email) to $($Team.DisplayName) teams as $($_.Role)"
      Add-TeamUser -User $_.Email -Role $_.Role -GroupId $NewTeam.GroupId
    } -End {
      Write-Verbose "Users succesfully added to the $($Team.DisplayName) team"
    }

    Write-Verbose "Add $($Team.Channels.Length) channels to $($Team.DisplayName) team"
    $Team.Channels | ForEach-Object -Begin {
      $Index = 0   
    } -Process {
      $Index = $Index + 1
      Write-Progress -Id 2 -ParentId 0 -Activity "Creation of a new channel" -Status "$($Index) of $($Team.Channels.Length) - Display Name: $($_.DisplayName), Membership Type: $($_.MembershipType)" -PercentComplete ($index/$Team.Channels.Length*100)   
      New-TeamChannel -DisplayName $_.DisplayName -MembershipType $_.MembershipType -GroupId $NewTeam.GroupId

      Write-Verbose "Check channel membership type"
      if('Private' -eq $_.MembershipType -And $_.Users.Length -gt 0) {
        Write-Verbose "Add $($_.Users.Length) users to $($_.DisplayName) private channel"
        $_.Users | ForEach-Object -Begin {
          $IndexUsers = 0 
          $UsersLength = $_.Users.Length
          $DisplayName = $_.DisplayName
        } -Process {
          $IndexUsers = $IndexUsers + 1
          Write-Progress -Id 3 -ParentId 2 -Activity "Add user to the private channel" -Status "$($IndexUsers) of $($UsersLength) - User: $($_.Email), Role: $($_.Role)" -PercentComplete ($IndexUsers/$UsersLength*100)   
          Write-Verbose "Adding $($_.Email) to $($DisplayName) private channel as $($_.Role)"
          Add-UserToPrivateChannel -DisplayName $DisplayName -Email $_.Email -Role $_.Role -GroupId $NewTeam.groupId
        } -End {
          Write-Verbose "Users succesfully added to the $($_.DisplayName) channel"
        }
      }
    } -End {
      Write-Verbose "Channels succesfully created"
    }
  }
  Catch {
    Write-Error "Message: [$($_.Exception.Message)]" -ErrorId B1
  }
}
Function Add-UserToPrivateChannel([string]$DisplayName, [string]$Email, [string]$Role, [string]$GroupId) {
  $MaxNumberOfAttemps = 5
  $Attemps = 0
  do {
    try {
      Write-Verbose "$($Attemps) attempt/s"
      Write-Verbose "Waiting $(60*$Attemps) seconds"
      Start-Sleep -s (60*$Attemps)
      Write-Verbose "Adding $($Email) to $($DisplayName) private channel"
      Add-TeamChannelUser -DisplayName $DisplayName -User $Email -GroupId $GroupId
      Write-Verbose "Check user role"
      if("Owner" -eq $Role){     
        Write-Verbose "Set $($Email) as owner of the $($DisplayName) private channel"
        Add-TeamChannelUser -DisplayName $DisplayName -User $Email -Role "Owner" -GroupId $GroupId
      } 
      break;
    } catch {
      $Attemps = $Attemps + 1
      if($_.Exception.ErrorCode -ne 404 -And $attemps -eq $MaxNumberOfAttemps){
        throw
      }
    }
  } while ($Attemps -lt $MaxNumberOfAttemps)
}

Write-Verbose "Generating secure password"
$SecurePassword = ConvertTo-SecureString -AsPlainText $Office365Password -Force
Write-Verbose "Generating PSCredential object"
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist $Office365Username, $SecurePassword;
Write-Verbose "Connecting to Microsoft Teams"
Connect-MicrosoftTeams -Credential $Credentials

Write-Verbose "Read JSON file from $($TeamsFilePath)"
$Json = Get-Content -Raw -Path $TeamsFilePath | ConvertFrom-Json
$Json.Teams | ForEach-Object -Begin {
  $Index = 0    
} -Process {
  $Index = $Index + 1
  Write-Progress -Id 0 -Activity "Creation of the teams" -Status "$($Index) of $($Json.Teams.Length) - Display Name: $($_.DisplayName),  Visibility: $($_.Visibility)" -PercentComplete ($Index/$Json.Teams.Length*100)
  New-MicrosoftTeam -Team $_  
} -End {
  Write-Host "Update completed" -ForegroundColor Green
}
