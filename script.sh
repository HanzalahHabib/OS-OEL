#!/bin/bash

# Define directories
PROJECT_DIR="$HOME/Documents/saylanitech/sadqah/sadqah-web"
BACKUP_DIR="$HOME/backup" 
DATE=$(date +'%Y-%m-%d')
BACKUP_PATH="$BACKUP_DIR/backup_$DATE"
REPORT_PATH="$BACKUP_DIR/report.txt"
LOG_PATH="$BACKUP_DIR/cleanup.log"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Initialize report and log files
echo "Backup and Cleanup Report - $DATE" > "$REPORT_PATH"
echo "Backup and Cleanup Log - $DATE" > "$LOG_PATH"

# Logging function
log_action() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_PATH"
}

# Step 1: Backup Files (older than 30 days)
echo "Starting Backup Now..." | tee -a "$LOG_PATH"
log_action "Starting Now..."

# Find and move files older than 30 days from /project to /backup
moved_files=0
for file in $(find "$PROJECT_DIR" -type f -mtime +30); do
    subdir=$(dirname "$file")
    backup_subdir="$BACKUP_PATH$subdir"
    mkdir -p "$backup_subdir"  # Create subdirectory in backup folder
    mv "$file" "$backup_subdir"  # Move the file
    log_action "Moved file: $file"
    echo "Moved file: $file" >> "$REPORT_PATH"
    ((moved_files++))
done

# Step 2: Cleanup Temporary Files (.tmp, older than 7 days)
echo "Starting Cleaning UP" | tee -a "$LOG_PATH"
log_action "Starting Cleaning UP"

deleted_files=0
for tmp_file in $(find "$PROJECT_DIR" -type f -name "*.tmp" -mtime +7); do
    rm -f "$tmp_file"  # Delete .tmp file
    log_action "Deleted file: $tmp_file"
    echo "Deleted file: $tmp_file" >> "$REPORT_PATH"
    ((deleted_files++))
done

# Step 3: Generate Summary Report
echo "Backup Summary:" >> "$REPORT_PATH"
echo "Total files moved: $moved_files" >> "$REPORT_PATH"
echo "Total files deleted: $deleted_files" >> "$REPORT_PATH"

# Calculate total space cleared
total_space=$(du -sh "$PROJECT_DIR" | cut -f1)
echo "Total space cleared: $total_space" >> "$REPORT_PATH"

# Step 4: Handle Edge Cases

# Check if /backup has enough space (example threshold: 80%)
backup_space=$(df "$BACKUP_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

if [ "$backup_space" -ge 80 ]; then
    echo "Warning: /backup directory is almost full ($backup_space%)!" >> "$REPORT_PATH"
    log_action "Warning: /backup directory is almost full ($backup_space%)"
fi

# Step 5: Permissions Handling
echo "Checking Permissions For the Process" | tee -a "$LOG_PATH"
log_action "Checking Permissions For the Process"

for file in $(find "$PROJECT_DIR" -type f); do
    if [ ! -r "$file" ]; then
        log_action "Permission error: Cannot read $file"
        echo "Permission error: Cannot read $file" >> "$REPORT_PATH"
    fi
    if [ ! -w "$file" ]; then
        log_action "Permission error: Cannot write to $file"
        echo "Permission error: Cannot write to $file" >> "$REPORT_PATH"
    fi
done

echo "Backup & Cleanup Completed Successfuly" | tee -a "$LOG_PATH"
log_action "Backup & Cleanup Completed Successfuly"
