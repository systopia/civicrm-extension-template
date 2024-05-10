#!/bin/bash

set -euo pipefail

readonly SCRIPT_PATH="$0"
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
readonly SCRIPT_NAME
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
readonly SCRIPT_DIR

usage() {
  cat <<EOD
Usage: $SCRIPT_NAME <extension dir>
Installs/updates the files from the extension template into an existing
CiviCRM extension. The placeholders in the .template files are replaced
appropriately. In case a file already exists you'll be asked how to proceed.
EOD
}

eexit() {
  echo "$1" >&2
  exit 1
}

getCommand() {
  which "$1" 2>/dev/null || eexit "Command $1 not found"
}

existsCommand() {
  which "$1" >/dev/null 2>&1
}

DIFF=$(getCommand "diff")
readonly DIFF
PHP=$(getCommand "php")
readonly PHP
SED=$(getCommand "sed")
readonly SED

GIT_MERGE_TOOL=$(git config --global merge.tool 2>&1 ||:)
if [ -n "$GIT_MERGE_TOOL" ]; then
  MERGE=$(git config --global "mergetool.$GIT_MERGE_TOOL.path" || getCommand "$GIT_MERGE_TOOL")
elif existsCommand meld; then
  MERGE=$(getcommand meld)
elif existsCommand kdiff3; then
  MERGE=$(getCommand kdiff3)
elif existsCommand kompare; then
  MERGE=$(getCommand kompare)
fi
readonly MERGE

getXml() {
  local -r filename="$1"
  local -r xpathExpression="$2"

  "$PHP" -r "\$simpleXml = simplexml_load_file('$filename'); echo (string) \$simpleXml->xpath('$xpathExpression')[0];"
}

installFile() {
  local sourceFile="$1"
  local -r sourceDir=$(dirname "$sourceFile")
  local -r targetDir="$2"

  local -r sourceFileBasename=$(basename "$sourceFile")
  local -r extension=${sourceFileBasename##*.}
  if [ "$extension" = "template" ] && [ "$sourceFileBasename" != phpstan.neon.template ]; then
    local -r isTemplate=1
    local -r targetFileBasename=${sourceFileBasename%.*}
    local targetFile="$targetDir/$sourceDir/$targetFileBasename"
    local -r tempFile=$(mktemp --tmpdir "testX.$targetFileBasename.XXXX")
    "$SED" \
      -e "s/{EXT_DIR_NAME}/$EXT_DIR_NAME/g" \
      -e "s/{EXT_SHORT_NAME}/$EXT_SHORT_NAME/g" \
      -e "s/{EXT_LONG_NAME}/$EXT_LONG_NAME/g" \
      -e "s/{EXT_MIN_CIVICRM_VERSION}/$EXT_MIN_CIVICRM_VERSION/g" \
      -e "s/{EXT_UCFIRST_SHORT_NAME}/$EXT_UCFIRST_SHORT_NAME/g" \
      "$sourceFile" >"$tempFile"
    sourceFile="$tempFile"
  else
    local -r isTemplate=0
    local targetFile="$targetDir/$sourceDir/$sourceFileBasename"
  fi

  if [ -e "$targetFile" ]; then
    if [ "$sourceFile" = "./tests/ignored-deprecations.json" ]; then
      # Keep ignored-deprecations.json as it is.
      return 0
    fi

    if [ -e "$sourceFile" ] && "$DIFF" -q "$sourceFile" "$targetFile" >/dev/null; then
      # No difference.
      if [ $isTemplate -eq 1 ]; then
        rm -f "$tempFile"
      fi

      return 0
    fi

    availableActions=("r" "n" "b" "d" "s")
    if [ -n "$MERGE" ]; then
      availableActions+=("m")
    fi

    action=""
    until [[ "$action" =~ [a-z] ]] && [[ "${availableActions[*]}" =~ ${action} ]]; do
      cat <<EOD
$targetFile already exists. What do you want to do?
  - Replace [r]
  - Copy as new file (extension .new) [n]
  - Backup first (extension .backup) [b]
  - Show diff [d]
  - Skip [s]
EOD
      if [ -n "$MERGE" ]; then
        echo "  - Merge [m]"
      fi

      read -r action
      # lowercase.
      action=${action,}

      if [ "$action" = "d" ]; then
        "$DIFF" -au "$sourceFile" "$targetFile" | less --quit-if-one-screen ||:
        echo ""
        action=""
      elif [ "$action" = "m" ] && [ -n "$MERGE" ]; then
        if ! "$MERGE" -o "$targetFile" "$sourceFile" "$targetFile" >/dev/null; then
          echo "Merge failed" >&2
          echo >&2
          action=""
        else
          if [ $isTemplate -eq 1 ]; then
            rm -f "$tempFile"
          fi

          return 0
        fi
      fi
    done

    case "$action" in
      n)
        targetFile+=".new"
      ;;
      b)
        mv "$targetFile" "$targetFile.backup"
      ;;
      s)
        if [ $isTemplate -eq 1 ]; then
          rm -f "$tempFile"
        fi

        return 0
      ;;
    esac
  fi

  mkdir -p "$(dirname "$targetFile")"

  if [ $isTemplate -eq 1 ]; then
    mv "$tempFile" "$targetFile"
  else
    cp "$sourceFile" "$targetFile"
  fi
}

main() {
  if [ ! $# = 1 ]; then
    usage >&2
    exit 1
  fi

  if [ "$1" = -h ] || [ "$1" == --help ]; then
    usage
    exit 0
  fi

  if [ -z "$MERGE" ]; then
    cat <<EOD
Merge is not available as option to resolve conflicts because neither meld,
kdiff3, nor kompare is installed.

EOD
  fi

  local extDir="$1"
  if [ ! -d "$extDir" ]; then
    eexit "$extDir is not a directory"
  fi
  extDir=$(realpath "$extDir")

  local -r infoXmlFile="$extDir/info.xml"
  if [ ! -f "$infoXmlFile" ] || [ ! -r "$infoXmlFile" ]; then
    eexit "$infoXmlFile is not a readable file"
  fi

  EXT_DIR_NAME=$(basename "$extDir")
  readonly EXT_DIR_NAME
  EXT_LONG_NAME=$(getXml "$infoXmlFile" @key)
  readonly EXT_LONG_NAME
  EXT_SHORT_NAME=$(getXml "$infoXmlFile" file)
  readonly EXT_SHORT_NAME
  EXT_UCFIRST_SHORT_NAME="${EXT_SHORT_NAME^}"
  readonly EXT_UCFIRST_SHORT_NAME
  EXT_MIN_CIVICRM_VERSION=$(getXml "$infoXmlFile" compatibility/ver)
  readonly EXT_MIN_CIVICRM_VERSION

  if [ "$EXT_DIR_NAME" != "$EXT_LONG_NAME" ]; then
    echo "Note: Extension directory name ($EXT_DIR_NAME) and extension long name ($EXT_LONG_NAME) differ"
    echo
  fi

  # Change directory so we can use relative file names.
  cd "$SCRIPT_DIR"
  # We use "read" in "installFile" so we cannot switch to a loop using "read".
  # shellcheck disable=SC2044
  for file in $(find . -type f -not -name USAGE.md -not -name "$SCRIPT_NAME" -not -path "./.git/*" -not -name "*~"); do
    installFile "$file" "$extDir"
  done
}

main "$@"
