#!/bin/bash
# PDF Signing Helper - Opens a PDF in Preview for signing/annotation
# Usage: pdf-sign <file.pdf>
#        pdf-sign                  # Opens file picker
#
# DIFFERENCE FROM THE UBUNTU VERSION:
# The Ubuntu script installs and drives Xournal++. macOS needs neither -
# Preview.app has Markup and stored signatures built in (Tools > Annotate >
# Signature), so there is nothing to install.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get PDF file
PDF_FILE="$1"

if [[ -z "$PDF_FILE" ]]; then
    # No argument - use the native file picker via AppleScript
    PDF_FILE=$(osascript -e 'POSIX path of (choose file with prompt "Select PDF to sign" of type {"pdf"})' 2>/dev/null || true)

    if [[ -z "$PDF_FILE" ]]; then
        print_warn "No file selected"
        echo ""
        echo "Usage: pdf-sign <file.pdf>"
        echo ""
        echo "Tips for signing in Preview:"
        echo "  1. Click the Markup toolbar button (pen tip icon)"
        echo "  2. Click the Signature button to insert a stored signature"
        echo "     - Create one via Trackpad, Camera, or iPhone"
        echo "  3. Use the Text tool (T) to add a date"
        echo "  4. File > Export as PDF, or just Cmd+S to save in place"
        exit 0
    fi
fi

# Validate file
if [[ ! -f "$PDF_FILE" ]]; then
    print_error "File not found: $PDF_FILE"
    exit 1
fi

ext="${PDF_FILE##*.}"
# Lowercase without bash 4's ${var,,} - macOS ships bash 3.2
ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
if [[ "$ext" != "pdf" ]]; then
    print_warn "File may not be a PDF: $PDF_FILE"
fi

print_info "Opening in Preview: $PDF_FILE"
echo ""
echo "Quick tips:"
echo "  - Markup toolbar (pen tip icon): shows the annotation tools"
echo "  - Signature button: insert a saved signature"
echo "  - Text tool (T): add a date or text"
echo "  - Cmd+S saves in place; File > Export as PDF for a copy"
echo ""

open -a Preview "$PDF_FILE"

print_info "Preview opened"
