#!/bin/bash

# Script to create hard links for satellite images
# Reads filenames from sat_img_fnames.txt and creates links in the media directory

set -euo pipefail

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FNAMES_FILE="${SCRIPT_DIR}/sat_img_fnames.txt"
# SOURCE_DIR="/home/kp.makarov@geoscan.lan/proj/nginx_data/soniks_v1_media/_satellites"
# TARGET_DIR="/home/kp.makarov@geoscan.lan/proj/nginx_data/soniks_v1_media/satellites"
SOURCE_DIR="/home/kp.makarov@geoscan.lan/proj/nginx_data/soniks_v1_media/satellites"
TARGET_DIR=${SOURCE_DIR}

SAMPLE_FILENAME="_sat_img_sample.jpg"
SAMPLE_FILE="${SOURCE_DIR}/${SAMPLE_FILENAME}"

# Check if input file exists
if [[ ! -f "${FNAMES_FILE}" ]]; then
    echo "Error: ${FNAMES_FILE} not found"
    exit 1
fi

if [[ ! -f "${SAMPLE_FILE}" ]]; then
    echo "Error: ${SAMPLE_FILE} not found"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "${TARGET_DIR}"

# Process each line in the filenames file
while IFS= read -r line || [[ -n "${line}" ]]; do
    # Skip empty lines and comments
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    
    # Extract the filename (part after 'satellites/')
    filename="${line#satellites/}"
    
    # Source file path

    # Target file path
    dst_file="${TARGET_DIR}/${filename}"
    
    # Create hard link (force to overwrite existing)
    ln -f "${SAMPLE_FILE}" "${dst_file}"
    echo "Linked: ${filename}"

done < "${FNAMES_FILE}"

echo "Done. Processed $(wc -l < "${FNAMES_FILE}") lines from ${FNAMES_FILE}"
