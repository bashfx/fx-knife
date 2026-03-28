#!/usr/bin/env bash
#===============================================================================
#  __  __     __   __     __     ______   ______    
# /\ \/ /    /\ "-.\ \   /\ \   /\  ___\ /\  ___\   
# \ \  _"-.  \ \ \-.  \  \ \ \  \ \  __\ \ \  __\   
#  \ \_\ \_\  \ \_\\"\_\  \ \_\  \ \_\    \ \_____\ 
#   \/_/\/_/   \/_/ \/_/   \/_/   \/_/     \/_____/ 
#
#   file and text manipulation kit
#
#===============================================================================
#-------------------------------------------------------------------------------
#$ name: knife.fx 
#$ author: qodeninja
#$ semver: 0.3.4 
#-------------------------------------------------------------------------------
#=====================================code!=====================================
# Dev Note: This is an early alpha version and will need to refactored later.
  
  # @ top
  SELF="APP_KNIFE";
  SELF_ARGS=("${@}");
  SELF_PATH="$0";
  readonly KINFE_PATH="${BASH_SOURCE[0]}";


#-------------------------------------------------------------------------------
# Boot
#-------------------------------------------------------------------------------

  _is_dir(){
    [ -n "$1" ] && [ -d "$1" ] && return 0;
    return 1;
  }

  if _is_dir "$FX_INC_DIR"; then
    _inc="$FX_INC_DIR";
    _app="$FX_APP_DIR";
  elif _is_dir "$FXI_INC_DIR"; then
    _inc="$FXI_INC_DIR";
    _app="$FXI_APP_DIR";
  else 
    printf "[ENV]. Cant locate [include] ($_inc). Fatal.\n";
    exit 1;
  fi

#-------------------------------------------------------------------------------
# Core Libraries
#-------------------------------------------------------------------------------

  source "$_inc/base.sh"; 

  if is_base_ready; then
    fx_smart_source stdfx    || exit 1;
    fx_smart_source stdutils || exit 1;
    fx_smart_source stderr   || exit 1;
  else
    error "Problem loading core libaries";
    exit 1;
  fi

  #_using( MD5 FIND GREP AWK DATE SED COLUMN );
#-------------------------------------------------------------------------------
# State Vars
#-------------------------------------------------------------------------------




# Global variables to store paths to external commands once checked
REALPATH_CMD=""
MD5_CMD="" # Will be md5sum or md5
COLUMN_CMD=""
DATE_CMD="" # Will be date (GNU or BSD)
FIND_CMD="" # Path to the find utility
SED_CMD="" # Path to sed utility
SED_INPLACE_OPT="" # Option for sed -i based on GNU/BSD


# KNIFE: Modular file utility for structured file introspection and manipulation

# --- Globals ---
KNIFE_DISABLE_HISTORY= #unused atm

KNIFE_ETC="$(xdg_init 'etc' 'fx/knife')";

if is_rw_dir "$KNIFE_ETC"; then
  KNIFE_KNOWN_FILES="$KNIFE_ETC/knife_known";
  KNIFE_HISTORY="$KNIFE_ETC/knife_history";
else
  KNIFE_HISTORY_DISABLED=1;
fi

BACKUP_SUFFIX=".bak"

# Safety and Development Modes
# Set to any non-empty value to disable interactive prompts for destructive ops.
DANGER_MODE="" # Example: DANGER_MODE="1"
# Set to any non-empty value to bypass initial DANGER_MODE warning prompt and enable recursive search anywhere.
DEV_MODE="${DEV_MODE:-}"    # Example: DEV_MODE="1"

# Directories to exclude from recursive searches (case-sensitive)
KNIFE_EXCLUDES=(
  ".git"
  "node_modules"
  "target"
  "dist"
  "build"
  "vendor"
)

# --- Color Definitions ---
# red=$'\x1B[31m';
# orange=$'\x1B[38;5;214m';
# green=$'\x1B[32m';
# blue=$'\x1B[36m';
# RESET=$'\x1B[0m';



#-------------------------------------------------------------------------------
# Core Includes
#-------------------------------------------------------------------------------

# Logs messages to stderr
#stderr() { printf "%s\n" "$@" >&2; }

# Standardized return codes
knife_success() { return 0; }
knife_fail() { return 1; }

# # Colorized logging functions (messages to stderr)
# error() { stderr "${red}$1${RESET}"; knife_fail; } # Note: knife_fail does not exit, sets return code
# warn()  { stderr "${orange}$1${RESET}"; }
# okay()  { stderr "${green}$1${RESET}"; }
# info()  { stderr "${blue}$1${RESET}"; }


#-------------------------------------------------------------------------------
# Core Utilities
#-------------------------------------------------------------------------------



# Checks for all required external dependencies at startup
__check_all_dependencies() {
  local missing_critical=0

  # Check for md5sum/md5
  cmd_wrapper "md5sum" "MD5_CMD"
  if [[ -z "$MD5_CMD" ]]; then
    cmd_wrapper "md5" "MD5_CMD" # Try macOS md5
  fi
  if [[ -z "$MD5_CMD" ]]; then
    error "Missing critical utility: md5sum or md5 (for hashing). Please install one."
    missing_critical=1
  fi

  # Check for realpath/greadlink/readlink -f
  cmd_wrapper "realpath" "REALPATH_CMD"
  if [[ -z "$REALPATH_CMD" ]]; then
    cmd_wrapper "greadlink" "REALPATH_CMD" # macOS GNU readlink
  fi
  # Fallback for readlink -f (standard readlink might not have -f)
  if [[ -z "$REALPATH_CMD" ]]; then
      if command -v readlink >/dev/null 2>&1 && readlink -f / >/dev/null 2>&1; then
          REALPATH_CMD=$(command -v readlink)
      fi
  fi
  if [[ -z "$REALPATH_CMD" ]]; then
    error "Missing critical utility: realpath or readlink -f (for canonical paths). Please install one."
    missing_critical=1
  fi

  # Check for date (for history formatting)
  cmd_wrapper "date" "DATE_CMD"
  if [[ -z "$DATE_CMD" ]]; then
    error "Missing critical utility: date (for history timestamps). Please install."
    missing_critical=1
  fi

  # Check for find (for search_here)
  cmd_wrapper "find" "FIND_CMD"
  if [[ -z "$FIND_CMD" ]]; then
    error "Missing critical utility: find (for search command). Please install."
    missing_critical=1
  fi

  # Check for sed (for file manipulation) and determine in-place option
  cmd_wrapper "sed" "SED_CMD"
  if [[ -z "$SED_CMD" ]]; then
    error "Missing critical utility: sed (for file manipulation). Please install."
    missing_critical=1
  else
    # Determine the correct sed in-place option (GNU vs. BSD)
    if "$SED_CMD" --version >/dev/null 2>&1; then # GNU sed
      SED_INPLACE_OPT="-i"
    elif "$SED_CMD" -i '' /dev/null 2>/dev/null; then # BSD sed, test with empty backup suffix
      SED_INPLACE_OPT="-i ''"
    else
      error "Cannot determine sed -i functionality. In-place edits may fail."
      missing_critical=1
    fi
  fi

  # Check for column (non-critical, for history formatting)
  cmd_wrapper "column" "COLUMN_CMD"
  if [[ -z "$COLUMN_CMD" ]]; then
    warn "Optional utility 'column' not found. History output may not be aligned."
  fi

  if [[ "$missing_critical" -eq 1 ]]; then
    exit 1 # Exit if critical dependencies are missing
  fi
  knife_success
}

# Helper to check if a file exists and report error if not
_require_file_arg(){
  local file="$1" err;
  if ! is_name "$file"; then
    err="Missing required filename argument.";
  elif ! is_rw_file "$file"; then
    err="No read-write file found at: '$file', check permissions.";
  else
    return 0;
  fi
  error "$err";
  return 1;
}

#-------------------------------------------------------------------------------
# Template.sh
# complete function set copied here as some debate whether this is
# kitchen sinking knife too much, some of the fx are from docx
#-------------------------------------------------------------------------------

  strip_leading_comment() {
    sed 's/^[[:space:]]*#[[:space:]]*//'; #dont strip all whitesapce just maybe one
  }

  escape_sed_replacement(){
    printf '%s\n' "$1" | sed 's/[\/&\\]/\\&/g'
  }

  deref_var() {
    local __varname="$1"
    [[ "$__varname" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    eval "printf '%s' \"\$${__varname}\""
  }

  expand_vars() {
    local raw="$1" output="" varname value
    local prefix rest matched=1  # default to no match
    while [[ "$raw" == *'$'* ]]; do
      prefix="${raw%%\$*}"
      rest="${raw#*\$}"
      varname=$(expr "$rest" : '\([a-zA-Z_][a-zA-Z0-9_]*\)')
      # If no valid varname, break
      [ -z "$varname" ] && break
      value=$(deref_var "$varname") #bash 3.2
      rest="${rest#$varname}"
      output+="$prefix$value"
      raw="$rest"
      matched=0;
    done
    output+="$raw";
    printf '%s\n' "$output";
    return $matched;
  }

  expand_line_vars(){
    local ret out lineX line="$1";

    [ "${opt_dev:-1}" -eq 0 ] && [ "${opt_silly:-1}" -eq 0 ] && silly "$line";

    if [[ "$line" == *'$'* ]]; then
      lineX=$(expand_vars "$line"); ret=$?;
      if [ "${opt_dev:-1}" -eq 0 ] && [ "${opt_silly:-1}" -eq 0 ]; then
        [ $ret -eq 0 ] && info "$lineX <--expanded";
        [ $ret -eq 1 ] && note "$lineX --> skipped";
      fi
      out="$lineX";
      ret=0;
    else
      out="$line";
      ret=1;
    fi
    echo -e "$out";
    return $ret;
  }

  replace_escape_codes(){
    local input ret res shebang esc_shebang;

    if [ -p /dev/stdin ]; then
      input="" # Initialize empty
      while IFS= read -r line || [[ -n $line ]]; do
        line=$(expand_line_vars "$line");ret=$?;
        input+=$line$'\n'
      done
    elif [ -n "$1" ]; then
      input="$1"
    else
      error "Error: No input provided to replace_escape_codes"
      return 1
    fi

    #shebang needs special babysitting for sed
    shebang="#!/usr/bin/env bash";
    esc_shebang=$(escape_sed_replacement "$shebang");

    #replace data
    input="${input//%date%/$(date +'%Y-%m-%d %H:%M:%S')}";

    # Replace color codes and glyphs.
    echo "$input" |
      sed "s|\${x}|$x|g" | sed "s|\${rev}|$revc|g" |
      sed "s|\${r}|$red|g" | sed "s|\${o}|$orange|g" | sed "s|\${c}|$cyan|g" |
      sed "s|\${g}|$green|g" | sed "s|\${isnek}|$snek|g" | sed "s|\${it}|$itime|g" |
      sed "s|\${id}|$delta|g" | sed "s|\${il}|$lambda|g" | sed "s|\${isp}|$spark|g" |
      sed "s|\${spark}|$spark|g" | sed "s|\${star}|$star|g" | sed "s|\${bolt}|$bolt|g" |
      sed "s|\${b2}|$blue2|g" | sed "s|\${w2}|$white2|g" | sed "s|\${p}|$purple|g" |
      sed "s|\${u}|$grey|g" | sed "s|\${y}|$yellow|g" | sed "s|\${b}|$blue|g" |
      sed "s|\${w}|$white|g" | sed "s|\${u2}|$grey2|g" | sed "s|\${r2}|$red2|g" |
      sed "s|\${bld}|$bld|g" | sed "s|\${line}|$line|g" | sed "s|\${LINE}|$LINE|g" |
      sed "s|\${ff}|$flag_on|g" | sed "s|\${fo}|$flag_off|g" | sed "s|\${shebang}|$esc_shebang|g"

    return 0
  }

  sed_block(){
    local id="$1" target="$2" pre="^[#]+[=]+" post=".*" str end;
    if [[ -f $target ]]; then
      str="${pre}${id}[:]?[^\!=\-]*\!${post}";
      end="${pre}\!${id}[:]?[^\!=\-]*${post}";
      sed -rn "1,/${str}/d;/${end}/q;p" "$target" | strip_leading_comment | replace_escape_codes;
      return 0;
    fi
    # Let the caller handle the error
    return 1;
  }

  block_print(){
    local lbl="$1" target="$2" IFS res ret;
    res=$(sed_block "$lbl" "$target"); ret=$?;
    if [ $ret -ne 0 ] || [ -z "$res" ]; then
      error "[KN] Block '$lbl' not found or empty in '$target'";
      return 1;
    fi
    inline_block_print "$res";
    return 0;
  }


  inline_block_print(){
    local res="$1" target="$2" IFS res ret;
    if [ -z "$res" ]; then
      error "[KN] Inline block content empty."
      return 1;
    fi
    printf '%s\n' "$res" | while IFS= read -r line; do
      if [[ $lbl =~ ^(doc|inf|rc|link|conf).* ]]; then
        printf '%b\n' "$line"
      else
        printf '%s\n' "$line"
      fi
    done
    return 0;
  }





  get_block(){
    local res ret src=$1 lbl=$2;
    res=$(sed -n "/#### ${lbl} ####/,/########/p" "$src");
    [ -z "$res" ] && ret=1 || ret=0;
    echo "$res";
    return $ret;
  }


	get_embedded_doc(){
    local str ret src=$1 lbl=$2;
    trace "Getting embedded link. (label=$lbl)";
    [ -z "$lbl" ] || [ -z "$src" ]||[ ! -f "$src" ]  && { 
      fatal "Cant read embedded doc invalid args ($1) ($2)";
      return 1;
    }
    str=$(block_print "$lbl" "$src");
    
    if [ ${#str} -gt 0 ]; then
      echo -e "$str"
    else 
      error "Problem reading embedded link";
      exit 1;
    fi
	}


#-------------------------------------------------------------------------------
#  Utilities
#-------------------------------------------------------------------------------


# Escapes special characters for use in sed literal string patterns
_escape_sed_pattern_literal() {
  printf "%s" "$1" | "$SED_CMD" 's/[][\/.^$*?+(){}|!]/\\&/g' # Escape common sed delimiters and regex metachars for literal match
}

# Checks if a file exists and is a shell script or .rc file
_is_shell_or_rc() {
  local file="$1"
  _require_file_arg "$file" || return 1
  # Check for shebang OR common RC file extensions/names
  grep -qE '^#!.*sh' "$file" || [[ "$(basename "$file")" =~ (\.sh|\.rc|\.profile|\.bashrc|\.zshrc|\.kshrc|\.cshrc|\.tcshrc|\.login)$ ]] || [[ "$(basename "$file")" =~ ^\.rc[a-zA-Z0-9_]*$ ]]
}

# Creates a backup of a file
_backup_file() {
  local file="$1"
  if _require_file_arg "$file"; then
    cp "$file" "$file$BACKUP_SUFFIX"
    okay "Backup created: ${file}${BACKUP_SUFFIX}"
    knife_success
  else
    warn "No file to backup: $file"
    knife_fail # Returns failure if no file to backup
  fi
}

# Returns the canonical path of a file
_canonical_path_of() {
  local file="$1"
  if [[ -n "$REALPATH_CMD" ]]; then
    "$REALPATH_CMD" "$file" 2>/dev/null || echo "$file"
  else
    # Fallback if REALPATH_CMD is not set (should not happen after __check_all_dependencies)
    echo "$file"
  fi
  # Removed redundant knife_success
}

# Returns MD5 hash of file content
_file_md5() {
  local file="$1"
  if _require_file_arg "$file"; then
    if [[ -n "$MD5_CMD" ]]; then
      if [[ "$MD5_CMD" =~ "md5sum" ]]; then
        "$MD5_CMD" "$file" | cut -d ' ' -f 1
      else # Likely 'md5' (macOS)
        "$MD5_CMD" -q "$file"
      fi
    else
      error "Hashing utility (md5sum/md5) not available."
      echo "" # Return empty string on failure
    fi
  else
    echo "" # Return empty string if file doesn't exist
  fi
  # Removed redundant knife_success
}

# Returns MD5 hash of a string
_string_md5() {
  local str="$1"
  if [[ -n "$MD5_CMD" ]]; then
    if [[ "$MD5_CMD" =~ "md5sum" ]]; then
      echo -n "$str" | "$MD5_CMD" | cut -d ' ' -f 1
    else # Likely 'md5' (macOS)
      echo -n "$str" | "$MD5_CMD" -q
    fi
  else
    error "Hashing utility (md5sum/md5) not available."
    echo "" # Return empty string on failure
  fi
  # Removed redundant knife_success
}

# Formats a Unix timestamp into a human-readable date string
__format_timestamp() {
  local timestamp="$1"
  if [[ -n "$DATE_CMD" ]]; then
    # Check for GNU date vs BSD/macOS date syntax
    if "$DATE_CMD" --version >/dev/null 2>&1; then # GNU date
      "$DATE_CMD" -d "@${timestamp}" "+%Y-%m-%d %H:%M:%S"
    else # BSD/macOS date
      "$DATE_CMD" -r "${timestamp}" "+%Y-%m-%d %H:%M:%S"
    fi
  else
    echo "${timestamp} (Date utility missing)"
  fi
}

# Checks if a path is within the user's home directory
_is_home_dir() {
  local path="$1"
  local abs_path=$(_canonical_path_of "$path")
  local home_abs=$(_canonical_path_of "$HOME")
  [[ "$abs_path" == "$home_abs" || "$abs_path" == "$home_abs"/* ]]
}

# Checks if a directory path is the root directory
_is_root_dir() {
  local path="$1"
  [[ "$path" == "/" ]]
}

# Checks if a command is destructive (modifies a file)
_is_destructive_command() {
  local cmd="$1"
  case "$cmd" in
    (setv|defv|link|inject|delete|unlink|metaset|metadel|cleanup) return 0 ;;
    (*) return 1 ;;
  esac
}

# --- Known Files Management ---

# Adds/updates a file's entry in .knife_known
_add_known_file() {
  local file="$1"
  if ! _require_file_arg "$file"; then knife_fail; fi

  local canon_path=$(_canonical_path_of "$file")
  local path_hash=$(_string_md5 "$canon_path")
  local content_hash=$(_file_md5 "$file")
  local filename=$(basename "$file")

  if [[ -z "$path_hash" || -z "$content_hash" ]]; then
    error "Cannot generate hash for $file due to missing utility. Skipping known file entry."
    knife_fail
  fi

  # Check if an entry with the exact path AND content hash already exists
  if grep -qE "^${canon_path}:${path_hash}:${content_hash}:${filename}$" "$KNIFE_KNOWN_FILES" 2>/dev/null; then
    knife_success
  else
    # Remove old entry if path exists but content has changed (or different hash)
    "$SED_CMD" "$SED_INPLACE_OPT" "/^${canon_path}:/d" "$KNIFE_KNOWN_FILES" 2>/dev/null || true # `|| true` to suppress error if file doesn't exist
    echo "${canon_path}:${path_hash}:${content_hash}:${filename}" >> "$KNIFE_KNOWN_FILES"
    knife_success # Explicit success needed as echo might not guarantee
  fi
}

# --- History Management ---

__get_next_history_id() {
  local last_id="0" # Default to 0
  if [[ -f "$KNIFE_HISTORY" && -s "$KNIFE_HISTORY" ]]; then # Check if file exists and is not empty
    # Try to extract the last ID. Use awk for robustness as it handles empty files better.
    last_id=$(awk -F: 'END {print $1}' "$KNIFE_HISTORY" 2>/dev/null)
    # Ensure it's numeric, otherwise fallback to 0
    if ! [[ "$last_id" =~ ^[0-9]+$ ]]; then
      last_id="0"
    fi
  fi
  printf "%04d" $((10#$last_id + 1)) # Convert to base 10, increment, then format back
}

# Logs a knife operation to .knife_history
__log_history() {
  local cmd_type="$1"
  local cmd_params="$2"
  local target_file="$3" # This is the file name as passed to knife, not canonical yet

  # Add to known files and get canonical details
  _add_known_file "$target_file" || return 1; # Ensure file is in known list and exists

  local id=$(__get_next_history_id)
  local timestamp=$(date +%s) # Using 'date' as it's checked by __check_all_dependencies
  local vanity_filename=$(basename "$target_file")
  local canon_path=$(_canonical_path_of "$target_file")
  local path_hash=$(_string_md5 "$canon_path")
  local content_hash=$(_file_md5 "$target_file") # Hash of the file *after* operation

  if [[ -z "$path_hash" || -z "$content_hash" ]]; then
    error "Cannot log history for $target_file: Hashing failed."
    knife_fail
  fi

  echo "${id}:${timestamp}:${cmd_type}:${cmd_params}:${vanity_filename}:${path_hash}:${content_hash}" >> "$KNIFE_HISTORY"
  # Removed redundant knife_success
}

# --- Main Knife Commands ---

# knife line <line_num> <file>
knife_line() {
  local line_num="$1" file="$2"
  _require_file_arg "$file" || return 1;
  "$SED_CMD" -n "${line_num}p" "$file"
  # Removed redundant knife_success
}

# knife lines quick <file>
knife_lines_quick() {
  local file="$1"
  _require_file_arg "$file" || return 1;
  wc -l < "$file"
  # Removed redundant knife_success
}

# knife banner <label> <file>
knife_banner() {
  local label="$1" file="$2"
  _require_file_arg "$file" || return 1;
  # Removed ^ anchor to allow banners not at start of line (e.g., after a source)
  local line_num=$(grep -nE "#+\\s*$label\\s*#+" "$file" | cut -d: -f1)
  if [[ -n "$line_num" ]]; then
      echo "$line_num"
  else
      info "Banner '${label}' not found in $file"
      knife_fail # Signal failure with return code, not -1
  fi
}

# knife block <label> <file>
knife_block() {
  local label="$1" file="$2"
  _require_file_arg "$file" || return 1
  awk "/### open:$label/{flag=1; next} /### close:$label/{flag=0} flag" "$file"
  # Removed redundant knife_success
}

# knife linked <fileA> <fileB>
knife_linked() {
  local fileA="$1" fileB="$2"
  _require_file_arg "$fileA" || return 1
  _require_file_arg "$fileB" || return 1
  # Match either canonical path or just basename for flexibility in existing source statements
  grep -qE "source +\"?($(_canonical_path_of "$fileA")|$(basename "$fileA"))\"?" "$fileB"
  if [[ $? -eq 0 ]]; then knife_success; else knife_fail; fi
}

# knife link <fileA> <fileB> (adds source statement)
knife_link() {
  local fileA="$1" fileB="$2"
  _require_file_arg "$fileA" || return 1
  _require_file_arg "$fileB" || return 1
  if ! _is_shell_or_rc "$fileB"; then
    error "Cannot link: $fileB is not a shell or .rc file."
    return 1 # Early exit on error
  fi
  if knife_linked "$fileA" "$fileB"; then # Use the new knife_linked
    warn "Already linked: ${fileA} in ${fileB}"
    knife_success
  else
    _backup_file "$fileB" || return 1
    echo "source \"$(_canonical_path_of "$fileA")\" # knife:link" >> "$fileB"
    __log_history "link" "$(basename "$fileA")" "$fileB"
    okay "Linked ${fileA} in ${fileB}"
    knife_success
  fi
}

# knife unlink <fileA> <fileB> (removes source statement)
knife_unlink() {
  local fileA="$1" fileB="$2"
  # Do not check fileA existence, as it might be deleted (unlink by label/line content)
  _require_file_arg "$fileB" || return 1
  if ! _is_shell_or_rc "$fileB"; then
    error "Cannot unlink: $fileB is not a shell or .rc file."
    return 1 # Early exit on error
  fi
  # Use knife_linked check for the presence of the link
  if ! knife_linked "$fileA" "$fileB"; then
    warn "Not linked: ${fileA} not found in ${fileB}"
    knife_success
  else
    _backup_file "$fileB" || return 1
    
    # Generate exact literal strings to delete
    local canonical_line="source \"$(_canonical_path_of "$fileA")\" # knife:link"
    local basename_line="source \"$(basename "$fileA")\" # knife:link" # Also consider if only basename was sourced
    
    # Escape these literal strings for sed's /pattern/ syntax
    local escaped_canonical_line=$(_escape_sed_pattern_literal "$canonical_line")
    local escaped_basename_line=$(_escape_sed_pattern_literal "$basename_line")

    # Attempt to delete the canonical path version
    "$SED_CMD" "$SED_INPLACE_OPT" "/${escaped_canonical_line}/d" "$fileB" 2>/dev/null
    # Attempt to delete the basename version (if different and not already deleted)
    if [[ "$canonical_line" != "$basename_line" ]]; then
        "$SED_CMD" "$SED_INPLACE_OPT" "/${escaped_basename_line}/d" "$fileB" 2>/dev/null
    fi
    
    __log_history "unlink" "$(basename "$fileA")" "$fileB"
    okay "Unlinked ${fileA} from ${fileB}"
    knife_success
  fi
}

# knife getv <key> <file>
knife_getv() {
  local key="$1" file="$2"
  _require_file_arg "$file" || return 1
  # Extract value after '=', strip trailing semicolons/comments and leading/trailing whitespace
  grep -E "^\s*${key}\s*=" "$file" | tail -n1 | cut -d= -f2- | "$SED_CMD" -E 's/;\s*$//;s/\s*#.*$//;s/^\s*//;s/\s*$//'
  # Removed redundant knife_success
}

# knife keys <file>
knife_keys() {
  local file="$1"
  _require_file_arg "$file" || return 1
  # Extract key-value pairs, then strip trailing semicolons/comments from the output
  grep -E '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=.*' "$file" | "$SED_CMD" -E 's/;\s*$//;s/\s*#.*$//'
  # Removed redundant knife_success
}

# knife val <value_pattern> <file>
knife_val() {
  local value_pattern="$1" file="$2"
  _require_file_arg "$file" || return 1
  # Search for lines where VALUE part contains the pattern (after first '=')
  # Then cut the line to only return the KEY name
  grep -E '^[A-Za-z_][A-Za-z0-9_]*\s*=[^=]*'"${value_pattern}"'.*' "$file" | cut -d= -f1 | "$SED_CMD" -E 's/^\s*//;s/\s*$//'
  # Removed redundant knife_success
}

# knife setv <key> <value> <file> (aliased by defv)
knife_setv() {
  local key="$1" value="$2" file="$3"
  _require_file_arg "$file" || return 1
  _backup_file "$file" || return 1
  if grep -qE "^\s*${key}\s*=" "$file"; then
    "$SED_CMD" "$SED_INPLACE_OPT" "s|^\s*${key}\s*=.*|${key}=${value}|" "$file"
    okay "Updated key '${key}' in ${file}"
  else
    echo "${key}=${value}" >> "$file"
    okay "Added key '${key}' to ${file}"
  fi
  __log_history "setv" "${key}=${value}" "$file"
  knife_success
}

# knife split <line_num> <file>
knife_split() {
  local line="$1" file="$2"
  _require_file_arg "$file" || return 1
  head -n "$line" "$file" > "${file}.part1"
  tail -n +$((line + 1)) "$file" > "${file}.part2"
  okay "Split ${file} into ${file}.part1 and ${file}.part2"
  echo "${file}.part1 ${file}.part2" # Output new filenames to stdout
  knife_success
}

# @todo : refactor there may be some issues with escaping/hydrating values.

# knife inject <src_file> <target_file>
knife_inject() {
  local src="$1" target="$2"
  local name=$(basename "$src") # Calculate name once

  _require_file_arg "$src" || return 1
  _require_file_arg "$target" || return 1

  if [[ -z "$name" ]]; then # Defensive check
    error "Cannot determine filename for injection marker from source: $src"
    return 1 # Early exit
  fi

  # Use grep -F for fixed string match of the marker
  if ! grep -Fq "### include:${name} ###" "$target"; then
    error "Injection marker '### include:${name} ###' not found in ${target}."
    return 1 # Ensure early exit if marker not found
  fi
  _backup_file "$target" || return 1
  # Use '|' as sed delimiter to avoid issues with '/' in path
  "$SED_CMD" "$SED_INPLACE_OPT" "\|### include:${name} ###|r ${src}" "$target"
  __log_history "inject" "$name" "$target"
  okay "Injected ${src} into ${target}"
  knife_success
}

  # knife delete <line_num> <file> (replaces with comment)
  knife_delete_line() {
    local line_num="$1" file="$2"
    _require_file_arg "$file" || return 1
    _backup_file "$file" || return 1
    # Replace content of line_num with a comment to preserve line count and mark deletion
    "$SED_CMD" "$SED_INPLACE_OPT" "${line_num}s/.*/#knife deleted line $(__format_timestamp "$(date +%s)")/" "$file"
    __log_history "delete" "$line_num" "$file"
    okay "Line ${line_num} in ${file} replaced with '#knife deleted line'."
    knife_success
  }

  # knife extract <label> <file> (alias for block)
  knife_extract() {
    knife_block "$@"
  }

  # knife meta <file>
  knife_meta() {
    local file="$1"
    _require_file_arg "$file" || return 1
    grep -E '^#\s*[A-Za-z_]+\s*:' "$file"
    # Removed redundant knife_success
  }

  # knife metaget <key> <file>
  knife_metaget() {
    local key="$1" file="$2"
    _require_file_arg "$file" || return 1
    # Match key, extract content after first colon, remove leading/trailing whitespace and trailing semicolons
    grep -E "^#\\s*${key}\\s*:" "$file" | head -n1 | cut -d: -f2- | "$SED_CMD" -E 's/;\s*$//;s/^\s*//;s/\s*$//'
    # Removed redundant knife_success
  }

  # knife metaset <key> <value> <file>
  knife_metaset() {
    local key="$1" value="$2" file="$3"
    _require_file_arg "$file" || return 1
    _backup_file "$file" || return 1
    local marker_line_num=$(grep -nE "^#\\s*${key}\\s*:" "$file" | head -n1 | cut -d: -f1)
    if [[ -n "$marker_line_num" ]]; then
      "$SED_CMD" "$SED_INPLACE_OPT" "${marker_line_num}s|^#\\s*${key}\\s*:.*|# ${key}: ${value}|" "$file"
      okay "Updated meta key '${key}' in ${file}"
    else
      # Find the last # comment line in the file
      local last_comment_line=$(grep -nE '^\s*#' "$file" | tail -n1 | cut -d: -f1)
      if [[ -n "$last_comment_line" ]]; then
        "$SED_CMD" "$SED_INPLACE_OPT" "${last_comment_line}a\\# ${key}: ${value}" "$file" # Append after last comment
      else
        echo "# ${key}: ${value}" >> "$file" # Append to end if no comments at all
      fi
      okay "Added meta key '${key}' to ${file}"
    fi
    __log_history "metaset" "${key}=${value}" "$file"
    knife_success
  }

  # knife metadel <key> <file>
  knife_metadel() {
    local key="$1" file="$2"
    _require_file_arg "$file" || return 1
    local marker_line_num=$(grep -nE "^#\\s*${key}\\s*:" "$file" | head -n1 | cut -d: -f1)
    if [[ -n "$marker_line_num" ]]; then
      _backup_file "$file" || return 1
      "$SED_CMD" "$SED_INPLACE_OPT" "${marker_line_num}d" "$file"
      __log_history "metadel" "${key}" "$file"
      okay "Deleted meta key '${key}' from ${file}"
    else
      warn "Meta key '${key}' not found in ${file}."
      knife_success
    fi
  }


  # @note : logo wont have marker sentinels you need to know which line numbers its on
  # @note : made this more general purpose as block by range n,m
  knife_block_range(){
    local src=$1 r1=${2:-3} r2=${3:-9};
    local logo=$(sed -n "${r1},${r2} p" $src)
    printf "%s" "${logo//#/ }";
  }

  # knife copy <source_file> <num_lines> <output_file>
  knife_copy_lines() {
    local file="$1" n="$2" out="$3"
    _require_file_arg "$file" || return 1
    head -n "$n" "$file" > "$out"
    okay "Copied first ${n} lines of ${file} to ${out}"
    knife_success
  }

  # knife has <pattern> <file>
  knife_has() {
    local pattern="$1" file="$2"
    _require_file_arg "$file" || return 1
    if grep -qE "$pattern" "$file"; then
      info "Pattern '${pattern}' found in ${file}."
      knife_success
    else
      # Changed to error() as per feedback
      error "Pattern '${pattern}' not found in ${file}."
      knife_fail
    fi
  }

  # knife show <pattern> <file>
  knife_show() {
    local pattern="$1" file="$2"
    _require_file_arg "$file" || return 1
    if ! grep -nE "$pattern" "$file"; then
      info "No matches found for '${pattern}' in ${file}."
    fi
    # Removed redundant knife_success
  }

  # knife history [ :fields... | :all ] [file_query...]
  knife_history() {
    local requested_fields=""
    local file_query_arg=""
    local field_map="id:0 time:1 cmd:2 params:3 vanity:4 path_hash:5 content_hash:6"
    # todo: must support bash 3.2
    local -A headers=(
      [id]="ID" [time]="Time"$'\t'$'\t' [cmd]="Command" [params]="Parameters"
      [vanity]="File"$'\t' [path_hash]="PathHash" [content_hash]="ContentHash"
    )

    # Parse arguments: colon-prefixed fields followed by file_query
    local arg
    for arg in "$@"; do
      if [[ "$arg" == :* ]]; then # It's a field argument
        local field_name="${arg#:}" # Remove leading colon
        if [[ "$field_name" == "all" ]]; then
          requested_fields="id,time,cmd,params,vanity,path_hash,content_hash"
          break # :all means no further field parsing
        elif [[ "$field_map" =~ "${field_name}:" ]]; then
          requested_fields="${requested_fields}${field_name},"
        else
          warn "Unknown field: ${field_name}. Skipping."
        fi
      else # It's part of the file query
        if [[ -z "$file_query_arg" ]]; then
          file_query_arg="$arg"
        else
          file_query_arg="${file_query_arg} ${arg}"
        fi
      fi
    done

    # Default fields if no fields specified and no query
    if [[ -z "$requested_fields" && -z "$file_query_arg" ]]; then
      requested_fields="time,cmd,vanity,path_hash" # Default for last operation
    fi
    requested_fields="${requested_fields%,}" # Trim trailing comma

    # todo not bash 3.2 compat
    local -a field_names=($(echo "$requested_fields" | tr ',' ' '))
    local -a field_indices=()
    local -a display_headers=()

    # Map field names to indices and build display headers
    local name index
    for name in "${field_names[@]}"; do
      index=$(echo "$field_map" | "$SED_CMD" -E "s/.*${name}:([0-9]).*/\1/")
      if [[ -n "$index" ]]; then
        field_indices+=("$index")
        display_headers+=("${headers[$name]}")
      fi
    done

    if [[ ! -f "$KNIFE_HISTORY" || ! -s "$KNIFE_HISTORY" ]]; then
      info "No history found in ${KNIFE_HISTORY}."
      knife_fail
    fi

    local output_data=""
    local history_lines=""

    # Determine if only the last line or all lines are processed
    if [[ -z "$requested_fields" ]] && [[ -z "$file_query_arg" ]]; then
      # Default: Show only the very last operation, for history file tail
      history_lines=$(tail -n 1 "$KNIFE_HISTORY")
    else
      history_lines=$(cat "$KNIFE_HISTORY")
    fi

    local id_h time_h cmd_h params_h vanity_h path_hash_h content_hash_h
    while IFS=':' read -r id_h time_h cmd_h params_h vanity_h path_hash_h content_hash_h; do
      local keep_line=1

      if [[ -n "$file_query_arg" ]]; then
        # Filter by query (matches vanity filename or path hash)
        if [[ ! "$vanity_h" =~ "$file_query_arg" && ! "$path_hash_h" =~ "$file_query_arg" ]]; then
          keep_line=0
        fi
      fi

      if [[ "$keep_line" -eq 1 ]]; then
        local current_output=""
        for ((j=0; j<${#field_indices[@]}; j++)); do
          local field_idx="${field_indices[j]}"
          local field_val=""
          case "$field_idx" in
            (0) field_val="$id_h" ;;
            (1) field_val=$(__format_timestamp "$time_h") ;;
            (2) field_val="$cmd_h" ;;
            (3) field_val="$params_h" ;;
            (4) field_val="$vanity_h" ;;
            (5) field_val="$path_hash_h" ;;
            (6) field_val="$content_hash_h" ;;
          esac
          # Append with actual tab character
          current_output="${current_output}${field_val}"$'\t'
        done
        # Add newline. `column` needs the tabs, so no trailing tab removal.
        output_data="${output_data}${current_output}"$'\n' 
      fi
    done <<< "$history_lines"

    if [[ -z "$output_data" ]]; then
      info "No history entries found matching your criteria."
      knife_fail
    else
      # Print headers
      printf "%s\t" "${display_headers[@]}" | "$SED_CMD" 's/\t$//' # Trim last tab
      echo ""
      # Print data using column for formatting, if available
      if [[ -n "$COLUMN_CMD" ]]; then
        printf "%s" "$output_data" | "$COLUMN_CMD" -s $'\t' -t # Use -s for tab, -t for table
      else
        printf "%s" "$output_data" # Raw tab-separated if column is missing
      fi
      knife_success
    fi
  }


  # knife search <pattern>
  knife_search_here() {
    local pattern="$1"
    local current_dir=$(pwd)

    if _is_root_dir "$current_dir"; then
      error "Searching in the root directory (/) is not allowed."
      knife_fail
    fi

    local find_args=("-type" "f") # Only search files
    local exclude_paths=()

    # Build exclude paths for find -not -path
    if [[ ${#KNIFE_EXCLUDES[@]} -gt 0 ]]; then
      local exclude_item
      for exclude_item in "${KNIFE_EXCLUDES[@]}"; do
        exclude_paths+=("-o" "-path" "*/${exclude_item}/*")
      done
      # Remove the leading -o and group with NOT
      unset 'exclude_paths[0]' # This is safe now because of the `if [[ ${#KNIFE_EXCLUDES[@]} -gt 0 ]]` check
      exclude_paths=("!" "(" "${exclude_paths[@]}" ")")
    fi

    local search_depth=""
    if ! _is_home_dir "$current_dir" && [[ -z "$DEV_MODE" ]]; then
      search_depth="-maxdepth 1"
      warn "Restricting search to current directory only. Set DEV_MODE or run from \$HOME for recursive search."
    fi

    info "Searching for '${pattern}' in files from ${current_dir}..."

    # Build the find command arguments safely in an array
    local -a find_cmd_args=("$current_dir")
    if [[ -n "$search_depth" ]]; then
      find_cmd_args+=("$search_depth")
    fi
    find_cmd_args+=("${find_args[@]}")
    find_cmd_args+=("${exclude_paths[@]}")
    
    # Corrected -exec for grep
    find_cmd_args+=("-exec" "grep" "-lE" "$pattern" "{}" "+")

    # Execute the find command directly using the command path
    local found_files
    # Capture stderr to suppress `grep: command not found` etc. if sh -c has issues
    found_files=$("$FIND_CMD" "${find_cmd_args[@]}" 2>/dev/null) # NOW USING FIND_CMD

    if [[ -z "$found_files" ]]; then
      info "No files found containing '${pattern}'."
      knife_fail
    else
      echo "$found_files"
      okay "Search complete. Found files containing '${pattern}'."
      knife_success
    fi
  }

  # knife cleanup
  knife_cleanup() {
    local num_removed=0
    local overall_success=0 # Tracks if at least one item was removed or if no issues occurred

    if [[ -z "$DANGER_MODE" ]]; then
      info "This will remove all Knife-related backups (.bak), split parts (.part1, .part2), and Knife's history/known files."
      info "Are you sure you want to proceed? (y/N)"
      read -r -p "Confirm: " response
      if ! [[ "$response" =~ ^[Yy]$ ]]; then
        error "Cleanup cancelled by user."
        return 1
      fi
    fi

    # 1. Remove backup files based on known files list
    info "Attempting to remove backup files (.bak)..."
    if [[ -f "$KNIFE_KNOWN_FILES" ]]; then
      local canon_path filename
      # Loop through unique canonical paths in known files to find potential backups
      # Use awk to get unique canonical paths (field 1) if there are duplicates due to hash changes
      awk -F: '{print $1}' "$KNIFE_KNOWN_FILES" | sort -u | while read -r canon_path; do
        local backup_file="${canon_path}${BACKUP_SUFFIX}"
        if [[ -f "$backup_file" ]]; then
          rm "$backup_file"
          if [[ $? -eq 0 ]]; then
            okay "Removed backup: ${backup_file}"
            num_removed=$((num_removed + 1))
          else
            warn "Failed to remove backup: ${backup_file}"
          fi
        fi
      done
      overall_success=1 # At least attempted to remove backups
    else
      info "No known files to check for backups."
    fi

    # 2. Remove split part files (*.part1, *.part2) - search only in current dir and HOME subdirs
    info "Attempting to remove split part files (*.part1, *.part2)..."
    local deleted_count=0
    # Use find with -delete which is more efficient
    # Adding -maxdepth 3 as originally intended for this specific find
    local found_and_deleted_count=$("$FIND_CMD" "$(pwd)" "$HOME" -maxdepth 3 -type f \( -name "*.part1" -o -name "*.part2" \) -print -delete 2>/dev/null | wc -l)
    
    if [[ "$found_and_deleted_count" -gt 0 ]]; then
        okay "Removed ${found_and_deleted_count} split files."
        num_removed=$((num_removed + found_and_deleted_count))
        overall_success=1
    else
      info "No split part files found."
    fi
    
    # 3. Remove Knife's internal state files
    info "Attempting to remove Knife's internal state files..."
    if [[ -f "$KNIFE_KNOWN_FILES" ]]; then
      rm "$KNIFE_KNOWN_FILES"
      if [[ $? -eq 0 ]]; then okay "Removed ${KNIFE_KNOWN_FILES}"; num_removed=$((num_removed + 1)); overall_success=1; else warn "Failed to remove ${KNIFE_KNOWN_FILES}"; fi
    else
      info "${KNIFE_KNOWN_FILES} not found."
    fi

    if [[ -f "$KNIFE_HISTORY" ]]; then
      rm "$KNIFE_HISTORY"
      if [[ $? -eq 0 ]]; then okay "Removed ${KNIFE_HISTORY}"; num_removed=$((num_removed + 1)); overall_success=1; else warn "Failed to remove ${KNIFE_HISTORY}"; fi
    else
      info "${KNIFE_HISTORY} not found."
    fi

    if [[ "$overall_success" -eq 1 ]]; then
      okay "Cleanup complete. Total files removed: ${num_removed}."
      knife_success
    else
      info "Cleanup finished. No Knife-related files were found to remove."
      knife_success # Still success if nothing was there to remove
    fi
  }

  _destructive_guard(){
    local cmd="$1" file_arg="$2" confirm_path='' canon_confirm_path='';

    if _is_destructive_command "$cmd"; then # Check if the command *type* is destructive
      confirm_path="$file_arg";

      if [[ "$cmd" == "cleanup" ]]; then
        confirm_path="$HOME" # Cleanup operates broadly, so use HOME as reference for prompt
      fi
      
      if [[ -n "$confirm_path" ]]; then # Only prompt if a relevant path can be determined
        canon_confirm_path=$(_canonical_path_of "$confirm_path")
        # Execute first conditional test, then chain with logical AND (&&)
        if [[ -z "$DANGER_MODE" ]] && ! _is_home_dir "$canon_confirm_path"; then
          warn "WARNING: You are attempting a destructive operation ('${cmd}') outside of your HOME directory:"
          warn "  Target: ${canon_confirm_path}"
          info "Are you sure you want to proceed? (y/N)"
          read -r -p "Confirm: " response
          if ! [[ "$response" =~ ^[Yy]$ ]]; then
            error "Operation cancelled by user."
            return 1 # Return failure to dispatch, which will propagate
          fi
          warn "[KN] User accepted potential destructive changes check.";
          # user accepted
          return 0;
        fi

      fi

    fi
    info "[KN] Passed destructive changes check. (Safe)";
    return 1; #not a destructive command
  }

  _danger_mode_guard(){
    # Initial DANGER_MODE warning and prompt
    if [[ -n "$DANGER_MODE" ]]; then
      warn "WARNING: Knife is running in DANGER_MODE! Destructive operations may proceed without confirmation."
      if [[ -z "$DEV_MODE" ]]; then
        info "Do you wish to continue? (y/N)"
        read -r -p "Confirm: " response
        if ! [[ "$response" =~ ^[Yy]$ ]]; then
          error "Knife exited due to DANGER_MODE. Rerun without DANGER_MODE or set DEV_MODE to bypass."
          exit 1
        fi
      fi
    fi
    return 0;
  }


# note : stderr introduces new opt_file_arg as a fix for this mess. --file=path (refactor later)
# todo : refactor this!
  _target_file(){
    local cmd="$1" file_arg='';
    # Determine file_arg based on NEW argument order
    case "$cmd" in
      (line|delete|split|has|show) file_arg="$2" ;; # <arg1> <file>
      (banner|block|meta|logo|lines|extract|keys|val) file_arg="$1" ;; # <label> <file> or <file> for meta/logo/keys/val
      (find) 
          if [[ "$arg1" == "key" ]]; then  # find <type> <file> or find <type> <key> <file>
            file_arg="$3"; # find key KEY FILE
          elif [[ "$arg1" == "values" ]]; 
          then file_arg="$2"; # find values FILE
          fi ;;
      (setv|defv) file_arg="$3" ;; # <key> <value> <file>
      (getv) file_arg="$2" ;; # <key> <file>
      (linked|link|unlink|inject) file_arg="$2" ;; # <src_file> <target_file>
      (copy) file_arg="$3" ;; # <source_file> <num_lines> <output_file> -> target is source file
      (metaget|metaset|metadel) file_arg="$2" ;; # <key> <file> for get/del, <key> <value> <file> for set
      (cleanup) ;; # Cleanup has its own internal prompt, so no external target file
      (*) ;; # Other commands (history, search) don't have a direct target file for this prompt logic
    esac
    echo "$file_arg";
  }





  usage(){
    noop;
    get_embedded_doc "$SELF_PATH" "doc:help"; 
    exit 1;
  }


  dispatch(){
    local call="$1" arg="$2"  cmd=''file_arg='' ret;

    file_arg=$(_target_file "$@");

    case $call in

      (lines)
        if [[ "$1" == "quick" ]]; then   # @note : this probably does need two part command
          knife_lines_quick "$2"; 
        else 
          error "Unknown 'lines' subcommand: $1"; return 1; 
        fi
      ;;
      (line)      cmd='knife_line' ;; # 2args
      (banner)    cmd='knife_banner'  ;; # 2args
      (block)     cmd='knife_block' ;; # 2args
      (blockr)    cmd='knife_block_range' ;; # 3args
      (logo)      cmd='knife_block_range' ;; # 3args#alias
      (linked)    cmd='knife_linked' ;; # 2args
      (link)      cmd='knife_link' ;; # 2args
      (unlink)    cmd='knife_unlink' ;; # 2args
      (getv)      cmd='knife_getv' ;; # 2args # getv KEY FILE
      (keys)      cmd='knife_keys';; # 1arg# keys FILE
      (val)       cmd='knife_val' ;; # 2args # val VALUE_PATTERN FILE
      (setv|defv) cmd='knife_setv' ;; # 3args # setv KEY VALUE FILE
      (split)     cmd='knife_split' ;; # 2args
      (inject)    cmd='knife_inject' ;; # 2args
      (delete)    cmd='knife_delete_line' ;; # 2args
      (extract)   cmd='knife_extract' ;; # 2args
      (meta)      cmd='knife_meta' ;; # 1arg
      (metaget)   cmd='knife_metaget' ;; # 2args
      (metaset)   cmd='knife_metaset' ;; # 3args
      (metadel)   cmd='knife_metadel' ;; # 2args
      (copy)      cmd='knife_copy_lines' ;; # 3args # copy SOURCE_FILE NUM_LINES OUTPUT_FILE
      (has)       cmd='knife_has' ;; # 2args
      (show)      cmd='knife_show' ;; # 2args
      (history)   cmd='knife_history' ;; #all args # Pass all remaining args directly for history
      (search)    cmd='knife_search_here' ;; # 1arg
      (cleanup)   cmd='knife_cleanup' ;;
      (help|?)    cmd="usage";;
      (noop)      cmd="noop";;
    esac

    if [ -n "$cmd" ] && function_exists "$cmd"; then
      shift # remove the command so we can pass the rest
      "$cmd" "$@";   # Pass all extra arguments if cmd is defined
      ret=$?;
    else
      __errbox "[KN] Knife Dispatch Error, could not find function ($cmd) for command ($call)";
    fi
    [ -n "$err" ] && fatal "$err";
    echo -ne "\n\n";

    return $ret;


  }


  main() {
    # Check all critical external dependencies at startup
    __check_all_dependencies || exit 1
    _danger_mode_guard;

    if [[ "$#" -eq 0 ]]; then
      usage;
    fi

    dispatch "$@" # Dispatch the command and its arguments
    # The return code of dispatch (and thus the last command executed) will be the script's exit code
  }







# --- Entry Point ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

  orig_args=("${@}")
  _options "${orig_args[@]}"; # global options

  # Filter out flags to get positional arguments for main().
  args=()
  for arg in "${orig_args[@]}"; do
    [[ "$arg" == -* ]] && continue
    args+=("$arg")
  done

  main "${args[@]}";
  exit $?;

fi

#-------------------------------------------------------------------------------
#=====================================!code=====================================


#====================================doc:help!==================================
# 
#
# 
# \t\t\t${b2}KNIFE ${o}[command..]${x} [args..] [file..] [--flags|-f] ${x}
#
# \t\t\t   BashFX Text and File Manipulation Kit
#
# \t${w2}--> Arguments${x}
# \t n   - number       | file      - target file for command | col - column parameter
# \t n,m - range values | src, dest - file operation targets  | out - output file      
# \t str - string text  | key ,val  - shell key or value 
#
# \t${w2}--> Analysis${x}
# \t${o}line   ${u} <n> <file>${x}   - print contents of file at line
# \t${o}lines  ${u}quick <file>${x}  - prints the number of lines in a file
# \t${o}has    ${u}<str> <file>${x}  - boolean test if file has string (anywhere) 
# \t${o}show   ${u}<str> <file>${x}  - show all lines in a file that match string (anywhere) 
# \t${o}search ${u}<str>${x}         - find all files in the current tree that match string
#
# \t${o}history ${u}<col> [file]${x} - find all files in the current dir tree that match string
# \t                      ${u2}:time :vanity :id :cmd :params :path_hash :content_hash (:all)
#
# \t${w2}--> Manipulation${x} 
# \t${o}delete ${u} <n> <file>${x}   - delete line N from file
# \t${o}split  ${u}<n> <file>${x}    - split a file into two at line N
# \t${o}inject ${u}<src> <dest>${x}  - copies the contents of file B into file A, at every include banner.
# \t${o}copy   ${u}<src> <n> <out>${x}  - copies n lines from src to out 
# \t${o}block  ${u}<lbl> <file>${x}   - prints block of a file delim by labeled sentinels [alias=extract]
# \t${o}blockr ${u}<lbl> <file>${x}   - prints block of a file via line number range (inclusive)
# \t${o}logo   ${u}<file> <n> <m>${x} - alias of blockr
#
# \t${w2}--> Linking${x}
# \t${o}link   ${u}<src> <dest>${x}  - bind two files together (source), such that A loads B
# \t${o}unlink ${u}<src> <dest>${x}  - remove the binding of two files
# \t${o}linked ${u}<src> <dest>${x}  - check if two files are linked
#
# \t${w2}--> Embedded Vars${x}
# \t${o}meta    ${u}<file>${x}             - dump all comment meta values # key:val found in a file
# \t${o}metaget ${u}<key> <file>${x}       - print a single meta value by key (if it exists) (mult?)
# \t${o}metaset ${u}<key> <val> <file>${x} - add or set a meta value, in a file
# \t${o}metadel ${u}<key> <file>${x}       - del a meta value from a file (mult?) 
#
# \t${w2}--> Shell Vars${x}
# \t${o}getv  ${u}<key> <file>${x}          - get the value(s) of a shell key found in a file
# \t${o}setv  ${u}<key> <val> <file>${x}    - set a shell key in a file [alias=defv]
# \t${o}keys  ${u}<file> ${x}               - list all shell keys in a file
# \t${o}val   ${u}<str> <file> ${x}         - fuzzy search for keys with partial value in a file
#
# \t${w2}--> Misc${x}
# \t${o}cleanup${x}                     - remove all artifacts created by knife
#
# \t${r}banner <lbl> <file>         - print the banner of a file delim by a flag sentinel (WIP)${x}
# \t${r}copyr  <src> <n> <m> <out>  - copies range n-m lines from src to out ${x}
#=================================!doc:help=====================================

