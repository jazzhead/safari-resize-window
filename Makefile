##############################################################################
#
# Makefile for Resize Window
#
# Website: http://jazzheaddesign.com/work/code/resize-window/
# Author:  Steve Wheeler
#
##############################################################################

# **BEFORE** tagging release, update version number.
#
# Version used for distributions (when there is no git repo).
VERSION       = 0.1.1

SHELL         = /bin/sh

# Make will use the current date when inserting the release date into the
# generated compiled script and README file. To override with a specific
# date, pass a date on the command-line when calling make, i.e.,
# `make RELEASE_DATE=YYYY-MM-DD`
RELEASE_DATE := $(shell date "+%F")


# If run from a git repo, then override the version above with
# a version derived from git tags formatted as `v[0-9]*`.
ifneq (,$(wildcard .git))
VERSION := $(subst v,,$(shell git describe --match "v[0-9]*" --dirty --always))
# NOTE: Remove the `--always` option to exit if git can't find a tag
#       instead of falling back to an abbreviated commit hash.
endif

# Format:  full_month_name day, year
RELEASE_DATE_FULL := $(shell date -j -f "%F" "$(RELEASE_DATE)" "+%B %e, %Y" \
                     | tr -s ' ')

# File names
SOURCE        = resize_window.applescript
BASENAME      = Resize\ Window
PACKAGE       = resize-window

# Locations
prefix        = $(HOME)
bindir        = $(prefix)/Library/Scripts/General
BUILD         = _build
DOC_DIR       = doc

# Output files
TARGET       := $(BASENAME).scpt
DOC_FILE     := $(BASENAME)\ README.rtfd
# Distribution archive file basename
ARCHIVE      := $(PACKAGE)-$(VERSION)

# Documentation source files (text files in concatenation order)
TEXT_FILES    = readme.md LICENSE
DOC_SRC      := $(patsubst %,$(DOC_DIR)/%,$(TEXT_FILES))
HTML_LAYOUT  := $(DOC_DIR)/layout.erb
FPO_DIR       = dev/fpo
# Temporary file
HTML_FILE    := $(DOC_DIR)/readme.html
# ed commands for tweaking RTF formatting
ED_COMMANDS  := $(DOC_DIR)/doc.ed.txt

# Output file paths
PROG         := $(BUILD)/$(TARGET)
DOC_TARGET   := $(BUILD)/$(DOC_FILE)

# For files or directories that have backslash-escaped spaces, make variables
# without the escapes to use for AppleScript (osascript)
TARGET_AS    := $(subst \,,$(TARGET))

# Tools
RM            = rm -rf
ED            = ed -s
SED           = LANG=C sed
MKDIR         = mkdir -p
MARKDOWN      = kramdown
MARKDOWN_OPT := --no-auto-ids --entity-output :numeric --template $(HTML_LAYOUT)
ARCHIVE_CMD   = ditto -c -k --sequesterRsrc --keepParent

# Set the type (-t) and creator (-c) codes when compiling just like
# AppleScript Editor does. The codes are useful for Spotlight searches.
# If the -t and -c options are omitted, no codes are set.
OSACOMPILE    = osacompile -t osas -c ToyS -o

# Install tool and options
INSTALL      = install
INSTDIR     := $(bindir)
INSTOPTS     = -pSv     # Don't use -b option; backups show up in script menu
INSTMODE     = -m 0600
INSTDIRMODE  = -m 0700


# ==== TARGETS ===============================================================

.PHONY: all install uninstall clean doc dist

all: $(PROG)

install: all
	$(call trash-installed,$(INSTDIR)/$(TARGET_AS))
	@echo "--->  Installing '$(TARGET)' into '$(INSTDIR)'..."
	@$(INSTALL) -dv $(INSTDIRMODE) $(INSTDIR) && \
	$(INSTALL) $(INSTOPTS) $(INSTMODE) $(PROG) $(INSTDIR)

uninstall:
	@echo "--->  Uninstalling '$(TARGET)' from '$(INSTDIR)'..."
	$(call trash-installed,$(INSTDIR)/$(TARGET_AS))

clean:
	@echo "--->  Deleting build files..."
	@[ -d "$(BUILD)" ] && $(RM) $(BUILD) || true
	@[ -f "$(HTML_FILE)" ] && $(RM) $(HTML_FILE) || true
	@echo "--->  Deleting distribution files..."
	@[ -d "$(ARCHIVE)" ] && $(RM) $(ARCHIVE) || true
	@$(RM) $(PACKAGE)-*.zip 2>/dev/null || true
	@echo "--->  Deletion complete"

doc: $(DOC_TARGET)

dist: all doc
	@echo "--->  Making a release..."
	@[ -d "$(ARCHIVE)" ] && $(RM) $(ARCHIVE) || true
	@[ -f "$(ARCHIVE).zip" ] && $(RM) $(ARCHIVE).zip || true
	@$(MKDIR) $(ARCHIVE)
	@cp -a $(BUILD)/* $(ARCHIVE)
	@cp -a $(FPO_DIR) $(ARCHIVE)
	@find $(ARCHIVE) -name .DS_Store -print0 | xargs -0 $(RM)
	@$(ARCHIVE_CMD) $(ARCHIVE) $(ARCHIVE).zip
	@$(RM) $(ARCHIVE)
	@echo "--->  Release distribution archive created"


# ==== DEPENDENCIES ==========================================================

$(PROG): $(SOURCE)
	@[ -d $(BUILD) ] || {  \
		echo "--->  Creating directory '$(BUILD)'..."; \
		$(MKDIR) $(BUILD);  \
	}
	@if [ 0 = $$(grep -cm1 '@@VERSION@@' $<) ]; then  \
		echo "--->  Compiling '$@' from '$<'...";     \
		$(OSACOMPILE) "$@" $<;  \
	else                        \
		echo "--->  Inserting VERSION number and compiling '$@' from '$<'..."; \
		$(call insert-version,"$<") | $(OSACOMPILE) "$@";  \
	fi
	@touch -r "$<" "$@"

$(DOC_TARGET): $(HTML_FILE)
	@echo "--->  Generating RTFD file from HTML..."
	@[ -d $(DOC_TARGET) ] && $(RM) $(DOC_TARGET) || true
	@[ -d $(BUILD) ] || $(MKDIR) $(BUILD)
	@textutil -format html -convert rtfd -output "$@" $<
	@echo "--->  Removing temporary HTML file..."
	@$(RM) $<
	@echo "--->  Tweaking RTF documentation formatting with 'ed' commands..."
	@$(ED) $(DOC_TARGET)/TXT.rtf < $(ED_COMMANDS) >/dev/null 2>&1
	@touch -r "$(DOC_DIR)/readme.md" "$@"
	@touch -r "$(DOC_DIR)/readme.md" $(DOC_TARGET)/TXT.rtf

$(HTML_FILE): $(DOC_SRC)
	@echo "--->  Concatenating Markdown files and generating temp HTML file..."
	@if ! which $(MARKDOWN) >/dev/null; then \
		echo "Can't find '$(MARKDOWN)' in PATH, needed for Markdown to HTML."; \
		false; \
	fi
	@# Make substitutions (version, etc.) before passing to Markdown parser
	@cat $^ | $(SED) -e 's/@@VERSION@@/$(VERSION)/g' -e 's/ (c) / \&copy; /g' \
		-e 's/[[:<:]]\(20[0-9][0-9]\)-\(20[0-9][0-9]\)[[:>:]]/\1--\2/g' \
		-e 's/@@RELEASE_DATE@@/$(RELEASE_DATE_FULL)/g' \
		| $(MARKDOWN) $(MARKDOWN_OPT) > $@
	@# Center the images since textutil ignores CSS margin auto on p > img
	@printf "%s\n" H \
	    'g/^\(<p\)\(><img \)/s//\1 style="text-align:center"\2/' . w | \
	    $(ED) $@ >/dev/null 2>&1


# ==== FUNCTIONS =============================================================

define trash-installed
	@echo "--->  Deleting installed script: '$1'"
	@osascript                                  \
	-e "tell application \"Finder\""            \
	-e "	if exists (POSIX file \"$1\") then" \
	-e "		delete (POSIX file \"$1\")"     \
	-e "	end if"                             \
	-e "end tell" >/dev/null
endef

define insert-version
	$(SED) -e 's/@@VERSION@@/$(VERSION)/g' \
		-e 's/@@RELEASE_DATE@@/$(RELEASE_DATE)/g' "$1"
endef

