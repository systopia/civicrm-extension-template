#!/bin/bash

set -euo pipefail

# Files that have been part of previous versions of the template.
readonly DELETED_FILES=(
  ci/README.md
  ci/composer.json
  tests/docker-compose.yml
  tests/docker-phpunit.sh
  tests/docker-prepare.sh
)

readonly FILE_REVISIONS_FILE=.template-file-revisions

readonly SCRIPT_PATH="$0"
SCRIPT_NAME=$(basename "$SCRIPT_PATH")
readonly SCRIPT_NAME
SCRIPT_DIR=$(dirname "$(realpath "$SCRIPT_PATH")")
readonly SCRIPT_DIR

usage() {
  cat <<EOD
Usage: $SCRIPT_NAME [OPTION] <extension dir> [<file_or_dir> ...]
  -f, --force
            Force installation if the installed revision matches the revision
            from the template or the file was removed.
  -h, --help
            Print this help.

Installs/updates the files from the extension template into an existing
CiviCRM extension. The placeholders in the .template files are replaced
appropriately. In case a file already exists you'll be asked how to proceed.

The files to install/update can be limited by specifying the files and
directories as arguments. This can be done by using absolute paths to
files/directories in the extension template or by using paths relative to the
directory of the extension template. The extension ".template" may be omitted.

The revision of each file is stored in a file named "$FILE_REVISIONS_FILE".
A file once installed won't be changed unless the revision changes or
installation is forced. If a file gets removed, it won't be reinstalled unless
installation is forced.
EOD
}

eexit() {
  echo "$1" >&2
  exit 1
}

getGitFileRevision() {
  local -r filename="$1"
  local commitCount
  local commitHash
  commitCount=$(git rev-list --count main "$filename")
  commitHash=$(git log -1 --format=%h "$filename")

  echo "$commitCount+$commitHash"
}

saveFileRevisions() {
  local -r extDir="$1"
  declare -p TEMPLATE_FILE_REVISIONS >"$extDir/$FILE_REVISIONS_FILE"
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

MERGE=""
GIT_MERGE_TOOL=$(git config --global merge.tool 2>&1 ||:)
if [ -n "$GIT_MERGE_TOOL" ]; then
  MERGE=$(git config --global "mergetool.$GIT_MERGE_TOOL.path" || getCommand "$GIT_MERGE_TOOL")
elif existsCommand kdiff3; then
  MERGE=$(getCommand kdiff3)
elif existsCommand kompare; then
  MERGE=$(getCommand kompare)
elif existsCommand meld; then
  MERGE=$(getCommand meld)
fi
readonly MERGE

getXml() {
  local -r filename="$1"
  local -r xpathExpression="$2"

  # Multiple spaces as well as line breaks are replaced by a single space.
  "$PHP" -r "\$simpleXml = simplexml_load_file('$filename'); echo preg_replace('/[\s]+/', ' ', (string) \$simpleXml->xpath('$xpathExpression')[0]);"
}

isVersionLesser() {
  "$PHP" -r "if (version_compare('$1', '$2', '>=')) exit(1);"
}

# Returns 200 if nothing has changed.
installFile() {
  local -r sourceFile="$1"
  # If the source file is a .template file contentFile is going to be overridden with a temp file.
  local contentFile="$sourceFile"
  local -r sourceDir=$(dirname "$sourceFile")
  local -r targetDir="$2"

  local -r sourceFileBasename=$(basename "$sourceFile")
  local -r extension=${sourceFileBasename##*.}
  if [ "$extension" = "template" ] && [ "$sourceFileBasename" != phpstan.neon.template ]; then
    local -r isTemplate=1
    local -r targetFileBasename=${sourceFileBasename%.*}
    local -r targetFile="$targetDir/$sourceDir/$targetFileBasename"
  else
    local -r isTemplate=0
    local -r targetFile="$targetDir/$sourceDir/$sourceFileBasename"
  fi
  local -r relativeTargetFile=$(realpath "$targetFile" --relative-to "$targetDir")

  local -r fileRevision=$(getGitFileRevision "$sourceFile")
  if [[ -v TEMPLATE_FILE_REVISIONS[$sourceFile] ]]; then
    if [ "${TEMPLATE_FILE_REVISIONS[$sourceFile]}" = "$fileRevision" ] && [ $FORCE -eq 0 ]; then
      # File wasn't changed in template since last installation.
      return 200
    fi

    if [ ! -e "$targetFile" ]; then
      # File had been installed once, but was removed later.
      if [ $FORCE -eq  0 ]; then
        return 200
      fi

      echo "$relativeTargetFile had been installed once, but was removed later."
      local answer=""
      until [ "$answer" = "y" ] || [ "$answer" = "n" ]; do
        echo -n "Do you want to install $relativeTargetFile again? [y/N] "
        read -r answer
        # lowercase.
        answer=${answer,}
        if [ -z "$answer" ]; then
          answer="n"
        fi
      done
      echo ""

      if [ "$answer" = n ]; then
        return 200
      fi
    fi
  fi

  if [ $isTemplate -eq 1 ]; then
    local -r tempFile=$(mktemp --tmpdir "testX.$targetFileBasename.XXXX")
    "$SED" \
      -e "s/{EXT_DIR_NAME}/$EXT_DIR_NAME/g" \
      -e "s/{EXT_SHORT_NAME}/$EXT_SHORT_NAME/g" \
      -e "s/{EXT_LONG_NAME}/$EXT_LONG_NAME/g" \
      -e "s/{EXT_MIN_CIVICRM_VERSION}/$EXT_MIN_CIVICRM_VERSION/g" \
      -e "s/{EXT_SHORT_NAME_CAMEL_CASE}/$EXT_SHORT_NAME_CAMEL_CASE/g" \
      -e "s/{EXT_NAME}/$EXT_NAME/g" \
      -e "s@{EXT_URL}@$EXT_URL@g" \
      -e "s/{EXT_AUTHOR}/$EXT_AUTHOR/g" \
      -e "s/{EXT_DESCRIPTION}/${EXT_DESCRIPTION//\//\\\/}/g" \
      "$sourceFile" >"$tempFile"
    cp --attributes-only --preserve=mode "$sourceFile" "$tempFile"
    contentFile="$tempFile"
  fi

  if [ -e "$targetFile" ]; then
    if "$DIFF" -q "$contentFile" "$targetFile" >/dev/null; then
      # No difference.
      if [ $isTemplate -eq 1 ]; then
        rm -f "$tempFile"
      fi

      TEMPLATE_FILE_REVISIONS[$sourceFile]=$fileRevision

      return 0
    fi

    availableActions=("r" "n" "b" "d" "i" "s")
    if [ -n "$MERGE" ]; then
      availableActions+=("m")
    fi

    action=""
    until [[ "$action" =~ ^[a-z]$ ]] && [[ "${availableActions[*]}" =~ ${action} ]]; do
      cat <<EOD
$relativeTargetFile already exists. What do you want to do?
  - Replace [r]
  - Copy as new file (extension .new) [n]
  - Backup first (extension .backup) [b]
  - Show diff [d]
  - Ignore [i]
  - Skip [s]
EOD
      if [ -n "$MERGE" ]; then
        echo "  - Merge [m]"
      fi

      read -r action
      # lowercase.
      action=${action,}

      if [ "$action" = "d" ]; then
        "$DIFF" -au "$contentFile" "$targetFile" | less --quit-if-one-screen ||:
        echo ""
        action=""
      elif [ "$action" = "m" ] && [ -n "$MERGE" ]; then
        if ! "$MERGE" -o "$targetFile" "$contentFile" "$targetFile" >/dev/null; then
          echo "Merge failed" >&2
          echo >&2
          action=""
        else
          if [ $isTemplate -eq 1 ]; then
            rm -f "$tempFile"
          fi

          TEMPLATE_FILE_REVISIONS[$sourceFile]=$fileRevision

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
      i)
        TEMPLATE_FILE_REVISIONS[$sourceFile]=$fileRevision
        if [ $isTemplate -eq 1 ]; then
          rm -f "$tempFile"
        fi

        return 0
      ;;
      s)
        if [ $isTemplate -eq 1 ]; then
          rm -f "$tempFile"
        fi

        return 200
      ;;
    esac
  fi

  mkdir -p "$(dirname "$targetFile")"

  if [ $isTemplate -eq 1 ]; then
    mv "$tempFile" "$targetFile"
  else
    cp "$contentFile" "$targetFile"
  fi

  TEMPLATE_FILE_REVISIONS[$sourceFile]=$fileRevision
}

main() {
  if [ -z "$MERGE" ]; then
    cat <<EOD
Merge is not available as option to resolve conflicts because neither meld,
kdiff3, nor kompare is installed. It's highly recommended to install a merge
tool!

EOD
  fi

  FORCE=0
  local extDir=""
  local path=""
  local paths=()

  while [ $# -gt 0 ]; do
    case "$1" in
      -f|--force)
        FORCE=1
      ;;
      -h|--help)
        usage
        exit 0
      ;;
      -*)
        eexit "Invalid option $1"
      ;;
      *)
        if [ -z "${extDir}" ]; then
          if [ ! -d "$1" ]; then
            eexit "$1 is not a directory"
          fi

          extDir=$(realpath "$1")
        else
          if [[ "$1" != /* ]]; then
            path="$SCRIPT_DIR/$1"
          else
            path="$(realpath "$1")"
          fi
          if [ ! -e "$path" ] && [ -f "$path.template" ]; then
            path+=.template
          fi
          if [ ! -e "$path" ] || [[ $path != $SCRIPT_DIR/* ]]; then
            eexit "$1 is not a file or directory in the extension template"
          fi

          paths+=("$path")
        fi
      ;;
    esac

    shift
  done

  if [ ${#paths[@]} -eq 0 ]; then
    paths=(.)
  fi

  if [ -z "${extDir}" ]; then
    usage
    exit 1
  fi

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
  EXT_SHORT_NAME_CAMEL_CASE=$("$SED" -r 's/(^|-|_)(\w)/\U\2/g' <<<"$EXT_SHORT_NAME")
  readonly EXT_SHORT_NAME_CAMEL_CASE
  EXT_MIN_CIVICRM_VERSION=$(getXml "$infoXmlFile" compatibility/ver)
  readonly EXT_MIN_CIVICRM_VERSION

  EXT_NAME=$(getXml "$infoXmlFile" name)
  readonly EXT_NAME
  EXT_URL=$(getXml "$infoXmlFile" urls/url)
  readonly EXT_URL
  EXT_DESCRIPTION=$(getXml "$infoXmlFile" description)
  readonly EXT_DESCRIPTION
  EXT_AUTHOR=$(getXml "$infoXmlFile" authors/author/name)
  [ -n "$EXT_AUTHOR" ] || EXT_AUTHOR=$(getXml "$infoXmlFile" maintainer/author)
  readonly EXT_AUTHOR

  if [ "$EXT_DIR_NAME" != "$EXT_LONG_NAME" ]; then
    echo "Note: Extension directory name ($EXT_DIR_NAME) and extension long name ($EXT_LONG_NAME) differ"
    echo
  fi

  if isVersionLesser "$EXT_MIN_CIVICRM_VERSION" 5.76; then
    echo "To run phpunit with GitHub Action at least CiviCRM 5.76 is required." >&2
    echo "You should adapt the minimum supported CiviCRM version in info.xml." >&2
    echo "Press Ctrl+C to cancel. Press enter to ignore this warning." >&2
    read -r
  fi

  declare -A TEMPLATE_FILE_REVISIONS
  if [ -f "$extDir/$FILE_REVISIONS_FILE" ]; then
    # Note: This cannot be done in a function (it would be available only in that function).
    # shellcheck source=/dev/null
    . "$extDir/$FILE_REVISIONS_FILE"
  fi

  # Change directory so we can use relative file names.
  cd "$SCRIPT_DIR"

  local file
  for path in "${paths[@]}"; do
      # We use "read" in "installFile" so we cannot switch to a loop using "read".
      # shellcheck disable=SC2044
      for file in $(find "$path" -type f -not -name README.md -not -name "$SCRIPT_NAME" -not -path "./.git/*" -not -name "*~" -not -name "*.orig"); do
        # Normalize file name so we can use it to access values in $TEMPLATE_FILE_REVISIONS
        file=$(realpath "$file" --relative-to "$SCRIPT_DIR")
        if installFile "$file" "$extDir"; then
          saveFileRevisions "$extDir"
        elif [ $? -ne 200 ]; then
          eexit "Installation of $file failed"
        fi
      done
  done

  if [ -x "$extDir/tools/git/init-hooks.sh" ]; then
    "$extDir/tools/git/init-hooks.sh"
  fi

  echo "Files have been installed."

  for deletedFile in "${DELETED_FILES[@]}"; do
    if [ -e "$extDir/$deletedFile" ]; then
      echo "$deletedFile was installed by a prior version of the template and isn't used anymore." >&2
      echo "You should consider deleting it." >&2
    fi
  done
}

main "$@"
