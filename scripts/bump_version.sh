#!/bin/bash

# Script to bump version in project.yml and update CHANGELOG.md

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <new_version>"
    echo "Example: $0 1.0.1"
    exit 1
fi

NEW_VERSION=$1

# Update project.yml MARKETING_VERSION and increment CURRENT_PROJECT_VERSION
# Using sed to find and replace the MARKETING_VERSION
sed -i '' "s/MARKETING_VERSION: .*/MARKETING_VERSION: $NEW_VERSION/" project.yml

# Increment CURRENT_PROJECT_VERSION
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION:" project.yml | awk '{print $2}')
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: .*/CURRENT_PROJECT_VERSION: $NEW_BUILD/" project.yml

echo "Successfully bumped version to $NEW_VERSION (Build $NEW_BUILD) in project.yml"
echo "Please remember to update CHANGELOG.md and commit the changes."
