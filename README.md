# Dependabot Alert to Jira Ticket Automation

This project automates the creation of Jira tickets for critical and high severity Dependabot alerts across multiple GitHub repositories using a scheduled GitHub Actions workflow and a Bash script.

---

## 📋 Features

- Scheduled daily execution via GitHub Actions
- Fetches open Dependabot alerts from multiple repositories
- Filters alerts by severity (`critical` and `high`)
- Checks Jira for existing tickets to avoid duplicates
- Creates detailed Jira bug tickets with labels and descriptions

---

## ⚙️ Setup Instructions

### 1. GitHub Secrets

Add the following secrets to your GitHub repository:

- `PAT_TOKEN`: GitHub Personal Access Token with repo access
- `PAT_JIRA`: Jira API token in the format `email:token`

---

### 2. Repository Structure

Place the Bash script in:

.github/config/create_jira_tickets.sh


Ensure the script is executable:

```bash
chmod +x .github/config/create_jira_tickets.sh
