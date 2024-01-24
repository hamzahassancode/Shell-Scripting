#!/bin/bash

# Function to display the help section
help_section() {
    echo "Usage: ./file_analysis.sh [directory_path] [extensions] [options]"
    echo "This script generates a comprehensive report of files in the given directory and its subdirectories based on specified criteria."
    echo
    echo "To search for files with multiple extensions simultaneously, use commas to separate the extensions (e.g., txt,sh)."
    echo "There are options to filter files based on size, permissions, or last modified timestamp, which can be used to customize your search criteria."
    echo "Options:"
    echo "  -h, --help             Display this help message."
    echo "  -s, --size             Filter files based on size of bytes (e.g., 100, 240), will give you the files with equal size or more."
    echo "  -p, --permissions      Filter files based on permissions (e.g., rw-, r-, rwx), will give you the files with these permissions."
    echo "  -m, --modified         Filter files based on last modified timestamp (e.g., 7, 1) variable to the desired number of days."
}

# Function to handle errors
display_error() {
    echo "Sorry, there is an error:"
    echo "$1"
    echo "Try to solve: $2"
    echo "Run './file_analysis.sh --help' for more help."
    echo "Try again..."
    exit 1
}

# Function to get file details
get_file_details() {
    file=$1
    # Retrieve multiple file details in a single stat command
    file_details=$(stat -c '%n:%s:%U:%A:%y' "$file")
    # Extract individual details from the output
    file_name=$(echo "$file_details" | cut -d':' -f1)
    size=$(echo "$file_details" | cut -d':' -f2)
    owner=$(echo "$file_details" | cut -d':' -f3)
    permissions=$(echo "$file_details" | cut -d':' -f4)
    last_modified=$(echo "$file_details" | cut -d':' -f5)
    echo "File: $file_name"
    echo "Size: $size bytes"
    echo "Owner: $owner"
    echo "Permissions: $permissions"
    echo "Last Modified: $last_modified"
    echo
}

# Check if the help option is provided
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    help_section
    exit 0
fi

# Check if a directory path is provided as an argument
if [[ -z "$1" ]]; then
    display_error "A directory path must be provided." "Enter the path in which you want to find the files."
fi

# Check if the provided directory exists
if [[ ! -d "$1" ]]; then
    display_error "The specified directory does not exist." "Make sure you typed the path correctly."
fi

# Check if extension is provided as an argument
if [[ -z "$2" ]]; then
    display_error "A file extension must be provided." "Enter the extension of the files you want to search for."
fi

if [[ $(($# % 2)) -eq 1 ]]; then
    display_error "It looks like you have an input error" "Make sure you have entered all fields"
fi

# Get the directory path
directory_path=$1

# Get the extensions
extensions=$(echo "$2" | tr ',' '|')  # Replace commas with OR operator

# Search for files based on the specified criteria
files=$(find "$directory_path" -type f | grep -E "(\.($extensions))")


filter_applied=false
criteria_filters=""

# Get the filter options and values
if [[ $# -gt 2 ]]; then
    shift 2 # Shift the arguments to skip the directory path and extensions
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--size)
                filter_applied=true
                size_filter="$2"
                criteria_filters+="size filter: $size_filter bytes or more, "
                files=$(du -b $files | awk -v size="$size_filter" '$1 >= size { print $2 }')
                shift 2
                ;;
            -p|--permissions)
                filter_applied=true
                permissions_filter="$2"
                criteria_filters+="permissions filter: $permissions_filter, "
                files=$(ls -l $files | grep "$permissions_filter" | awk '{ print $NF }')
                shift 2
                ;;
            -m|--modified)
                filter_applied=true
                modified_filter="$2"
                criteria_filters+="modified filter: last $modified_filter days, "
                files=$(find $files -type f -mtime -$modified_filter)
                shift 2
                ;;
            *)
                display_error "Invalid option: $1" "To see the available options, you can"
                ;;
        esac
    done
fi

# Check if any files are found
if [[ -z "$files" ]]; then
    display_error "Cannot find any files with the specified extension in the specified directory and its subdirectories." "It seems that no files meet the criteria you specified. Please verify that you have entered the extension and options accurately."
fi

# Create the file_analysis.txt report
report="file_analysis.txt"

# Iterate over the files and generate the report
echo "Generating file analysis report..."
echo
echo "------------Search Criteria------------" > "$report"
echo "Directory: $directory_path" >> "$report"
echo "Extensions: $extensions" >> "$report"
if [[ $filter_applied = true ]]; then
    echo "Filters Applied: " >> "$report"
    echo "$criteria_filters" >> "$report"
fi
echo "================================" >> "$report"
echo >> "$report"

# Group the files by owner
owners=$(echo "$files" | xargs -n1 stat -c '%U' | sort | uniq)

for owner in $owners; do
    echo "Owner: $owner" >> "$report"
    echo "--------------------------------" >> "$report"

    # Sort the files by size within each owner
    group_files=$(echo "$files" | xargs -n1 stat -c '%U:%s:%n' | grep "^$owner" | sort -t':' -k2 -rn | cut -d':' -f3)
    for file in $group_files; do
        get_file_details "$file" >> "$report"
    done

    echo >> "$report"
done

echo "================================" >> "$report"
echo "" >> "$report"

# Function to get summary statistics
get_summary_statistics() {
    file_count=$(echo "$files" | wc -l)
    total_size=$(du -cb $files | awk 'END { print $1 }')
    total_owners=$(echo $owners | wc -w)
    echo "------------Summary Statistics------------"
    echo "Total Files: $file_count"
    echo "Total Size: $total_size bytes"
    echo "Number of Owners: $total_owners"
    echo "Owners Names:"
    echo "$owners"
    echo
}

# Generate the summary statistics
get_summary_statistics >> "$report"
get_summary_statistics

echo "File analysis report generated successfully in '$report'."
