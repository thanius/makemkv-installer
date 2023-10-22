#!/bin/bash

# MakeMKV installer
# AUTHOR: Tobias Hellgren <thanius@chuggybumba.com>
# VERSION: 1.2

# Change this whenever the path has been moved
# Chouldn't be that often
PAGE="https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224"

# Regex for fetching download URLs
MAKEMKV="(?<=\")https:\/\/.*makemkv-(?:bin|oss)-.*.tar.gz(?=\")"

# Check for super user privilege
if [ $(whoami) != "root" ]; then
   echo "Please run this script as root, then follow on screen instructions."
   exit 0
fi

# Download the page
DOWNLOAD=$(curl -s "$PAGE")

# Get APT command and required packages
APT=$(echo "$DOWNLOAD"|grep -m1 -oP '(?<=<code>).*(?=</code>)')
PACKAGES=$(echo "$APT"|grep -oP '(?<=sudo apt-get install).*')

# Check if packages are installed and install as required
for PKG in $PACKAGES; do
   CHECK=$(dpkg-query -W --showformat='${Status}\n' $PKG 2>/dev/null|grep -oP "(?<=install )ok(?= installed)")

   if [[ -z $CHECK && $CHECK != "ok" ]]; then
      INSTALL+="$PKG "
   fi
done

if [[ -z $INSTALL ]]; then
   echo "All requirements met, continuing..."
else
   echo "Installing missing requirements..."
   apt install -y $INSTALL
fi

# Create temp dir
TEMP=$(mktemp -d)

# Get download URLs
URLS=$(echo "$DOWNLOAD"|grep -oP $MAKEMKV)
echo "Downloading MakeMKV..."

for URL in $URLS; do
   FILE=$(echo $URL|grep -oP 'makemkv-.*.tar.gz')
   OUTPUT="$TEMP/$FILE"
   curl -s $URL -o $OUTPUT
done

# Jump into temp directory to build and install
cd $TEMP

# Extract files
for ARCHIVE in *.tar.gz; do
   tar xf "$ARCHIVE"
done

# Build and install
for DIRECTORY in $(ls -d */); do
   cd $DIRECTORY

   # Only run the configure script if we're in the open source package
   # Otherwise, accept license
   if [[ $(echo $DIRECTORY|grep -oP "oss") == "oss" ]]; then
     ./configure
   else
     { printf 'q'; printf 'yes\r'; } | script -q /dev/null -c 'make'
   fi

   # Build and install into /usr/local
   make && make install

   # Go back to temp
   cd ..
done

# Cleanup
rm $TEMP -rf

echo "Done!"
