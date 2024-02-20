#!/bin/bash -x
# Most recently from
# https://github.com/mathiasbynens/dotfiles/blob/master/.macos

## SSD related

# Disable hibernation (speeds up entering sleep mode)
sudo pmset -a hibernatemode 0

IMAGE=/private/var/vm/sleepimage

# Capture the sleep image's existing permissions
perms=$(stat -f '%p' ${IMAGE})
# Remove the sleep image file to save disk space
sudo rm "${IMAGE}"
# Create a zero-byte file instead
sudo touch "${IMAGE}"
# Give it the permissions it had
sudo chmod "$perms" "${IMAGE}"
# and make sure it can't be rewritten
sudo chflags uchg "${IMAGE}"

# Disable the sudden motion sensor as it is not useful for SSDs
sudo pmset -a sms 0

## Safari & WebKit

# Privacy: don't send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Automatically quit printer app once the print jobs complete
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

# Screenshots
# Save screenshots to my Downloads
defaults write com.apple.screencapture location -string "${HOME}/Downloads"

# Save screenshots in JPEG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "jpeg"
