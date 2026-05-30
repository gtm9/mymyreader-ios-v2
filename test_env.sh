#!/bin/bash
xcodebuild test \
  -project VoiceNotes.xcodeproj \
  -scheme VoiceNotes \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.2' | grep -i "XCTest"
