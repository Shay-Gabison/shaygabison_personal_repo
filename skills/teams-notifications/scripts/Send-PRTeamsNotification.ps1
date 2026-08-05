<#
.SYNOPSIS
    Sends a Teams notification for a pull request
.DESCRIPTION
    Posts a formatted notification to Microsoft Teams channel or chat using Graph API.
    The message content should be provided by the caller.

.PARAMETER PullRequestId
    The ID of the pull request
.PARAMETER Message
    The formatted notification message
.PARAMETER Description
    Optional PR description to include in the card
.PARAMETER WorkItemId
    Optional work item ID to add a link button
.PARAMETER Destination
    Teams destination name as defined in the configuration file (e.g., PRChannel, MyTeamChat).
    Must match a key in the Destinations hashtable of Send-PRTeamsNotification.config.ps1.
.PARAMETER DryRun
    Preview the payload and target URI without sending the message.
.EXAMPLE
    .\Send-PRTeamsNotification.ps1 -PullRequestId 12345 -Message "..." -Destination PRChannel
.EXAMPLE
    .\Send-PRTeamsNotification.ps1 -PullRequestId 12345 -Message "..." -Description "Full PR description..." -WorkItemId 35705156 -Destination MyTeamChat
.EXAMPLE
    .\Send-PRTeamsNotification.ps1 -PullRequestId 12345 -Message "..." -Destination PRChannel -DryRun
.NOTES
    Requires: Azure CLI authenticated with 'az login'
    Uses Microsoft Graph API to post to Teams
#>

param(
    [Parameter(Mandatory=$true)][int]$PullRequestId,
    [Parameter(Mandatory=$true)][string]$Message,
    [Parameter(Mandatory=$false)][string]$Description,
    [Parameter(Mandatory=$false)][int]$WorkItemId,
    [Parameter(Mandatory=$true)]
    [string]$Destination,
    [Parameter(Mandatory=$false)][switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Load configuration from external file
# Look for config in project root (current working directory), then fallback to script dir
$ConfigPath = Join-Path (Get-Location) "Send-PRTeamsNotification.config.ps1"
if (-not (Test-Path $ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot "Send-PRTeamsNotification.config.ps1"
}
if (-not (Test-Path $ConfigPath)) {
    Write-Error "Configuration file not found. Expected: Send-PRTeamsNotification.config.ps1 in your project root."
    Write-Host "Copy templates/Send-PRTeamsNotification.config.ps1 from the teams-notifications skill to your project root and fill in {{PLACEHOLDER}} values." -ForegroundColor Yellow
    exit 1
}

try {
    $Config = & $ConfigPath
    $Organization = $Config.Organization
    $Project = $Config.Project
    $Repository = $Config.Repository
    $DestinationConfig = $Config.Destinations
}
catch {
    Write-Error "Failed to load configuration: $($_.Exception.Message)"
    Write-Host "Check that Send-PRTeamsNotification.config.ps1 is valid PowerShell." -ForegroundColor Red
    exit 1
}

# Validate configuration
if (-not $Organization -or -not $Project -or -not $Repository) {
    Write-Error "Configuration incomplete: Organization, Project, and Repository are required"
    exit 1
}

if (-not $DestinationConfig -or $DestinationConfig.Count -eq 0) {
    Write-Error "Configuration incomplete: At least one Teams destination must be configured"
    exit 1
}

# Validate destination exists in config
if (-not $DestinationConfig.ContainsKey($Destination)) {
    $validDestinations = $DestinationConfig.Keys -join ', '
    Write-Error "Invalid destination: '$Destination'. Available destinations: $validDestinations"
    exit 1
}

try {
    Write-Host "Sending Teams notification for PR #$PullRequestId..." -ForegroundColor Green
    
    # Initialize temp file variable
    $tempFile = $null
    
    # Construct PR URL
    $PullRequestUrl = "https://dev.azure.com/$Organization/$Project/_git/$Repository/pullrequest/$PullRequestId"
    
    # Get destination configuration
    $config = $DestinationConfig[$Destination]
    if (-not $config) {
        throw "Invalid destination: $Destination"
    }
    
    # Create Adaptive Card message content
    $cardBody = @(
        @{
            type = "TextBlock"
            text = "Pull Request #$PullRequestId"
            weight = "Bolder"
            size = "Large"
        }
        @{
            type = "TextBlock"
            text = $Message
            wrap = $true
            separator = $true
        }
    )
    
    # Add description if provided (truncate to 500 chars for Teams display)
    if ($Description) {
        $truncatedDesc = if ($Description.Length -gt 500) {
            $Description.Substring(0, 497) + "..."
        } else {
            $Description
        }
        
        $cardBody += @{
            type = "TextBlock"
            text = $truncatedDesc
            wrap = $true
            isSubtle = $true
            separator = $true
        }
    }
    
    $attachmentId = [guid]::NewGuid().ToString()
    
    # Build actions array
    $actions = @(
        @{
            type = "Action.OpenUrl"
            title = "View Pull Request"
            url = $PullRequestUrl
        }
    )
    
    # Add work item button if WorkItemId is provided
    if ($WorkItemId) {
        $WorkItemUrl = "https://dev.azure.com/$Organization/$Project/_workitems/edit/$WorkItemId"
        $actions += @{
            type = "Action.OpenUrl"
            title = "View Work Item #$WorkItemId"
            url = $WorkItemUrl
        }
    }
    
    $adaptiveCard = @{
        id = $attachmentId
        contentType = "application/vnd.microsoft.card.adaptive"
        content = ConvertTo-Json -Depth 10 @{
            '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
            type = "AdaptiveCard"
            version = "1.4"
            body = $cardBody
            actions = $actions
        }
    }
    
    $messageBody = @{
        body = @{
            contentType = "html"
            content = "<attachment id=`"$attachmentId`"></attachment>"
        }
        attachments = @($adaptiveCard)
    }

    # Convert to JSON
    $body = $messageBody | ConvertTo-Json -Depth 10

    # Write body to temp file to avoid escaping issues
    $tempFile = [System.IO.Path]::GetTempFileName()
    $body | Out-File -FilePath $tempFile -Encoding UTF8

    # Determine Graph API URI based on destination type
    if ($config.TeamId -and $config.ChannelId) {
        # Channel message
        $uri = "https://graph.microsoft.com/v1.0/teams/$($config.TeamId)/channels/$($config.ChannelId)/messages"
        Write-Host "Sending to channel: $Destination" -ForegroundColor Gray
    }
    elseif ($config.ChatId) {
        # Chat message
        $uri = "https://graph.microsoft.com/v1.0/chats/$($config.ChatId)/messages"
        Write-Host "Sending to chat: $Destination" -ForegroundColor Gray
    }
    else {
        throw "Invalid destination configuration"
    }

    # Send the Teams message using Azure CLI
    if ($DryRun) {
        Write-Host ""
        Write-Host "[dry-run] Would POST to: $uri" -ForegroundColor Cyan
        Write-Host "[dry-run] Payload:" -ForegroundColor Cyan
        Get-Content $tempFile | Write-Host
        Write-Host ""
        Write-Host "[dry-run] No message was sent." -ForegroundColor Cyan
        exit 0
    }

    az rest --uri $uri --method POST --body "@$tempFile" --headers "Content-Type=application/json" --resource "https://graph.microsoft.com/"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Teams notification sent successfully!" -ForegroundColor Green
        Write-Host "PR $PullRequestId - $PullRequestUrl" -ForegroundColor Gray
    } else {
        throw "Failed to send Teams notification"
    }
}
catch {
    Write-Error "Error sending Teams notification: $($_.Exception.Message)"
    Write-Host "Make sure you're authenticated with 'az login'" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up temp file
    if ($tempFile -and (Test-Path $tempFile)) {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}
