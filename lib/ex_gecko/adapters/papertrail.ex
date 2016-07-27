
"""
Interacts with papertrail cli to get latest logs, so that we can send to geckobard
papertrail -S "API Requests" --min-time '120 minutes ago' | grep -e "service=\d\d\d\dms"
"""
