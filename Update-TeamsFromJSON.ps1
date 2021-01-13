Param( 
    [Parameter(Position=0)]
    [string]$Office365Username = '',
    [Parameter(Position=1)]
    [string]$Office365Password = '', 
    [Parameter(Position=2)]
    [string]$TeamsFilePath = '.\teams.json'
)

# Import modules
$Module = Get-Module -Name MicrosoftTeams -ListAvailable 
if($Module.Count -eq 0) {   
  Install-Module -Name MicrosoftTeams -AllowPrerelease -AllowClobber -Force
}

# Functions
Function New-MicrosoftTeam([object]$Team) {
  Try {
    # Create new Team
    $NewTeam = New-Team -DisplayName $Team.DisplayName -Visibility $Team.Visibility

    # Add user to Team
    $Team.Users | ForEach-Object -Begin {
      $Index = 0   
    } -Process {
      $Index = $Index + 1
      Write-Progress -Id 1 -ParentId 0 -Activity "Add user to the team" -Status "$($Index) of $($Team.Users.Length) - User: $($_.Email), Role: $($_.Role)" -PercentComplete ($Index/$Team.Users.Length*100)
      Add-TeamUser -User $_.Email -Role $_.Role -GroupId $NewTeam.GroupId
    } -End {
      Write-Host "Add user to the team completed" -ForegroundColor Green
    }

    # Create channels
    $Team.Channels | ForEach-Object -Begin {
      $Index = 0   
    } -Process {
      $Index = $Index + 1
      Write-Progress -Id 2 -ParentId 0 -Activity "Creation of a new channel" -Status "$($Index) of $($Team.Channels.Length) - Display Name: $($_.DisplayName), Membership Type: $($_.MembershipType)" -PercentComplete ($index/$Team.Channels.Length*100)   
      New-TeamChannel -DisplayName $_.FisplayName -MembershipType $_.MembershipType -GroupId $NewTeam.GroupId

      if('Private' -eq $_.MembershipType -And $_.Users.Length -gt 0) {
        $_.users | ForEach-Object -Begin {
          $IndexUsers = 0 
          $UsersLength = $_.Users.Length
          $DisplayName = $_.DisplayName
        } -Process {
          $IndexUsers = $IndexUsers + 1
          Write-Progress -Id 3 -ParentId 2 -Activity "Add user to the private channel" -Status "$($IndexUsers) of $($UsersLength) - User: $($_.Email), Role: $($_.Role)" -PercentComplete ($IndexUsers/$UsersLength*100)   
          AddUserToPrivateChannel -DisplayName $DisplayName -Email $_.Email -Role $_.Role -GroupId $NewTeam.groupId
        } -End {
          Write-Host "Add user to the private channel completed" -ForegroundColor Green
        }
      }
    } -End {
      Write-Host "Creation of a new channel completed" -ForegroundColor Green
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
      Start-Sleep -s (60*$Attemps)
      Add-TeamChannelUser -DisplayName $DisplayName -User $Email -GroupId $GroupId
      if("Owner" -eq $Role){     
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

# Connect to MS Teams
$SecurePassword = ConvertTo-SecureString -AsPlainText $Office365Password -Force
$Credentials = New-Object -TypeName System.Management.Automation.PSCredential -Argumentlist $Office365Username, $SecurePassword;
Connect-MicrosoftTeams -Credential $Credentials

# Read teams file
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