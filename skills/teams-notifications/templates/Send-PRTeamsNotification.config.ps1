# Teams Notification Configuration Template
# This is a TEMPLATE file - copy it to Send-PRTeamsNotification.config.ps1 and customize
# 
# Setup Instructions:
# 1. Copy this file: cp Send-PRTeamsNotification.config.template.ps1 Send-PRTeamsNotification.config.ps1
# 2. Edit Send-PRTeamsNotification.config.ps1 with your actual values
# 3. Commit Send-PRTeamsNotification.config.ps1 to your repository
# 4. DO NOT commit this template file with real IDs
#
# To find Teams IDs:
# - Use Microsoft Graph Explorer (https://developer.microsoft.com/graph/graph-explorer)
# - Or use Teams admin center
# - Team ID: Found in Teams admin center or Graph API
# - Channel ID: Use Graph API /teams/{team-id}/channels
# - Chat ID: Use Graph API /chats
# - See: https://learn.microsoft.com/en-us/graph/api/resources/teams-api-overview

# Azure DevOps Configuration
$Configuration = @{
    # Azure DevOps Settings
    # Replace these with your actual values
    Organization = "{{YOUR_ADO_ORG}}"           # e.g., "mycompany" from dev.azure.com/mycompany
    Project = "{{YOUR_PROJECT_NAME}}"           # Your Azure DevOps project name
    Repository = "{{YOUR_REPOSITORY_NAME}}"     # Your repository name
    
    # Teams Destinations
    # Define where PR notifications should be sent
    # You can have multiple destinations for different teams/purposes
    Destinations = @{
        # Example 1: Teams Channel (for public notifications)
        PRChannel = @{
            TeamId = "{{YOUR_TEAM_ID}}"         # Microsoft Teams Team ID
            ChannelId = "{{YOUR_CHANNEL_ID}}"   # Channel ID within the team
        }
        
        # Example 2: Group Chat (for specific team notifications)
        MyTeamChat = @{
            ChatId = "{{YOUR_CHAT_ID}}"         # Microsoft Teams Chat ID
        }
        
        # Add more destinations as needed:
        # BackendTeam = @{
        #     TeamId = "{{BACKEND_TEAM_ID}}"
        #     ChannelId = "{{BACKEND_CHANNEL_ID}}"
        # }
        # SecurityTeam = @{
        #     ChatId = "{{SECURITY_CHAT_ID}}"
        # }
    }
}

# Return configuration (do not modify this line)
return $Configuration
