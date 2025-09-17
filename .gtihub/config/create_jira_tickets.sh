#!/bin/bash

# List of GitHub repositories to scan for Dependabot alerts
REPOS=(
    "repo-1"
    "repo-2"
    "repo-3"
    # Add more repositories as needed
)

# GitHub and Jira credentials (set via GitHub Secrets in the workflow)
GITHUB_TOKEN="$PAT_TOKEN"
JIRA_AUTH="$PAT_JIRA"
JIRA_BASE_URL="https://your-domain.atlassian.net/rest/api/3/issue"
JIRA_PROJECT_KEY="YOUR_PROJECT_KEY"

# Loop through each repository
for repo in "${REPOS[@]}"; do
  # GitHub API endpoint for Dependabot alerts
  api_url="https://api.github.com/repos/your-org/$repo/dependabot/alerts"

  # Fetch alerts from GitHub
  alerts=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" "$api_url")

  # Skip if no alerts or empty response
  if [ -z "$alerts" ] || [ "$alerts" == "[]" ]; then
    echo "No alerts found for $repo."
    continue
  fi

  # Skip if GitHub API returns an error message
  if echo "$alerts" | jq -e '.message' >/dev/null 2>&1; then
    echo "Error fetching alerts for $repo."
    continue
  fi

  # Filter only open alerts
  open_alerts=$(echo "$alerts" | jq '[.[] | select(.state == "open")]')

  # Further filter alerts by severity: critical or high
  filtered_alerts=$(echo "$open_alerts" | jq '[.[] | select(.security_advisory.severity == "critical" or .security_advisory.severity == "high")]')

  echo "Repository: $repo"
  echo "Total Open Alerts: $(echo "$filtered_alerts" | jq '. | length')"

  # Extract relevant fields from each alert and process them
  echo "$filtered_alerts" | jq -r '.[] | "\(.security_advisory.severity)\n\(.security_advisory.description | gsub("[^a-zA-Z0-9 ]"; ""))\n\(.security_advisory.summary)\n\(.number)"' | while read -r severity; read -r description; read -r summary; read -r number; do

    # Proceed only if summary and description are present
    if [ -n "$summary" ] && [ -n "$description" ]; then
      LABEL="$repo-$number"

      # Check Jira for existing ticket with the same label
      JQL_QUERY="project = \"$JIRA_PROJECT_KEY\" AND labels = \"$LABEL\""
      RESPONSE=$(curl -s -u "$JIRA_AUTH" -X GET \
        -H "Accept: application/json" \
        -G --data-urlencode "jql=$JQL_QUERY" \
        "https://your-domain.atlassian.net/rest/api/3/search?maxResults=50")

      TICKET_COUNT=$(echo "$RESPONSE" | jq '.total')

      # Skip if ticket already exists
      if [ "$TICKET_COUNT" -gt 0 ]; then
        echo "Ticket already exists for $LABEL. Skipping."
        continue
      fi

      # Construct Jira ticket payload
      jira_payload=$(jq -n \
        --arg description "$description" \
        --arg repo "$repo" \
        --arg summary "$summary" \
        --arg severity "$severity" \
        --arg number "$number" \
        '{
          fields: {
            project: { key: "YOUR_PROJECT_KEY" },
            issuetype: { name: "Bug" },
            summary: "[\($severity)] \($summary) - \($repo)",
            description: {
              type: "doc",
              version: 1,
              content: [{
                type: "paragraph",
                content: [{ type: "text", text: $description }]
              }]
            },
            labels: ["dependabot", "\($repo)-\($number)"]
          }
        }')

      # Create Jira ticket
      curl -s -X POST -H "Content-Type: application/json" \
        -u "$JIRA_AUTH" \
        --data "$jira_payload" \
        "$JIRA_BASE_URL"
    fi
  done
done
