#!/bin/bash

# ==============================================================================
#  start_and_push.sh
#
#  This script automates the process of:
#  1. Stopping any old ngrok instances.
#  2. Starting a new ngrok TCP tunnel for SSH on port 22.
#  3. Using the ngrok API to get the public URL.
#  4. Saving the URL to a file named 'connected_info.log'.
#  5. Committing the file to Git with a timestamped message.
#  6. Pushing the commit to the 'origin' remote.
# ==============================================================================

# Stop any previously running ngrok instances to avoid conflicts
echo "INFO: Stopping any existing ngrok processes..."
killall ngrok &> /dev/null
sleep 1

# Start the new ngrok tunnel in the background
echo "INFO: Starting new ngrok tunnel for SSH (port 22)..."
ngrok tcp 22 --log=stdout > connecting_details.log &

# Give ngrok a moment to establish the connection and start its API
echo "INFO: Waiting for tunnel to establish..."
sleep 4

# Query the local ngrok API to get the tunnel's public URL
# The 'jq' tool is required to parse the JSON response
echo "INFO: Fetching public URL from ngrok API..."
PUBLIC_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')

# Check if the URL was successfully retrieved
if [[ -z "$PUBLIC_URL" || "$PUBLIC_URL" == "null" ]]; then
    echo "ERROR: Failed to fetch ngrok URL. Please check if ngrok is running correctly."
    killall ngrok # Clean up the failed ngrok process
    exit 1
fi

# Save the public URL to the log file
echo "$PUBLIC_URL" > connected_info.log
echo "SUCCESS: Connection info saved to connected_info.log:"
cat connected_info.log
echo ""

# --- Git Automation ---

# Add the updated connection file to the staging area
echo "INFO: Staging connected_info.log for commit..."
git add connected_info.log
git add connecting_details.log

# Create a dynamic commit message with the current time and date
COMMIT_MESSAGE=$(date +"connection info at %T, %d/%m/%Y")
echo "INFO: Committing with message: \"$COMMIT_MESSAGE\""
git commit -m "$COMMIT_MESSAGE"

# Push the commit to the 'origin' remote.
# 'HEAD' refers to the current branch, so you don't need to specify the branch name.
echo "INFO: Pushing changes to origin..."
git push origin HEAD

echo ""
echo "SUCCESS: Script finished. Your connection info is now in your Git repository."
