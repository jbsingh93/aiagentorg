---
name: cancel-org
description: "Stop a running continuous operation loop started by /run-org. Cleans up the loop state file."
disable-model-invocation: true
user-invocable: true
allowed-tools: Read, Bash
---

# Cancel Organisation Loop

Stop the continuous operation loop started by `/run-org`.

## Step 1: Check for active loop

Check if `org/.loop-state.md` exists.

## Step 2: If active loop found

1. Read the file to get the current iteration count and start time
2. Delete the file: `rm org/.loop-state.md`
3. Confirm to the user:
   ```
   Organisation loop stopped.
   - Ran for {N} cycles since {START_TIME}
   - Loop state file removed
   
   The org is now in manual mode. Use /heartbeat for single cycles or /run-org to restart continuous operation.
   ```

## Step 3: If no active loop

Tell the user: "No active organisation loop found. Nothing to cancel."
