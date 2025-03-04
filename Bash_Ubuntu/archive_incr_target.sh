#!/bin/bash

# Help menu
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    printf "### archive_incr_target.sh Help menu ###\n"
    printf "Param 1: target directory, wich will be archived"
    printf "Param 2: vault directory, where the archives will be stored. Ending with /"
    printf "Param 3: archive name, usually <hostname>/<drive-name>\n\n###"
    exit 0
fi

# Paths & name - main parameter
target_dir=$1 # Insert Path like SMB etc.
vault_dir=$2 # Insert Storage Path here, ending with /
archive_name=$3 # Optionally implement an automated naming scheme here

# modular strings
backup_filename="${archive_name}.tar.xz" # .xz for Schwarzenegger-grade-compression
backup_path="${vault_dir}${backup_filename}"
snapshot_name="${archive_name}-snapshot"
log_file="${archive_name}.log"

# logging function
log() {
    local timestamp=$(date +"%Y-%m-%d_%H:%M:%S") # reversed european date format
    echo "[$timestamp] => $1" >> "${vault_dir}${log_file}"  # Write message & timestamp to log file
}

# Metadata
count=$(ls -l | grep -c $archive_name)
uncompressed_size=$(du -sh "$target_dir" | cut -f1)

### program ###
# Make sure the vault directory exists
mkdir -p "$vault_dir"

# Start the archive process
log "Starte Komprimierung nach $backup_path..."
log "Unkomprimierte Größe von ${target_dir}: $uncompressed_size"

tar -czg "$snapshot_name" -f "${vault_dir}${count}-${archive_name}" 

log "Größe der komprimierten Archive in ${vault_dir}: " + $(du -sh "${vault_dir}" | cut -f1)
log "Backup abgeschlossen!"
