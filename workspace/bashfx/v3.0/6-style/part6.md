# Part VI: Coding Style & Best practices

This section outlines explicit stylistic and structural requirements for all BashFX code, ensuring readability, maintainability, and consistency.

### 6.0 Coding Style & Best Practices

-   **0. Instructions are Debatable:** Sometimes errors pop their head into an unexpected context. If you encounter a rule or instruction that causes syntax errors or defects by virtue of its definition, then please flag your coding partner about the inconsistent rule before following blindly. If a rule causes an unexpected defect downsteam that you are aware of, also flag that!

-   **1. Semicolon Usage:** A semicolon **must** be used to terminate a statement when it is followed by another command on the same line (e.g., `command1; command2`) or when it's syntactically required by Bash (e.g., before `;;` in `case` statements). The lack of semicolons in chained commands (e.g., with `&&`, `||`, or `|`) is a common source of preventable errors. Logic block keywords (`fi`, `done`) do not take a trailing semicolon.

    **Examples:**
    ```bash
    # Same-line termination
    ret=0; log "Success";

    # Chained commands (required for correctness)
    mkdir -p "$dir" && cd "$dir" || fatal "Could not create or enter directory";
    ```

-   **2. Block Termination:** `if`, `while`, `for`, `until` logic blocks **must** be terminated with `fi`, `done`, `done`, `done` respectively. Do not use a trailing semicolon after these keywords. Function definitions are terminated with `}`.

    **Examples:**
    ```bash
    # Simple 'if' block
    if [[ -n "$var" ]]; then
        log "Variable is not empty";
    fi

    # Simple 'while' block
    while read -r line; do
        log "Read line: $line";
    done < "file.txt"
    ```

-   **3. Case Statements:** `case` statements **must** enclose patterns in parentheses (`(pattern)`) and use double semicolons (`;;`) for termination of each pattern block.

    **Example:**
    ```bash
    case "$command" in
        (start)
            do_start_service;
            ;;
        (stop)
            do_stop_service;
            ;;
        (*)
            usage;
            ;;
    esac
    ```

-   **4. Function Granularity:** Prioritize breaking down large functions into smaller helpers, adhering to the principles of **Function Ordinality (see Section 4.0)**. This separation of concerns is key to maintainability.

| Function Type       | Example Name          | Responsibility                                          |
| :------------------ | :-------------------- | :------------------------------------------------------ |
| **High-Order**      | `do_process`     | Manages user interaction, guards, and orchestrates the flow. |
| **Mid-Level Helper**  | `_read_lines`    | Performs a discrete sub-task, like reading a file into an array. |
| **Low-Level Literal** | `__count_items` | Performs a single, "close to the metal" task, like counting array elements. |

-   **5. Underscore Naming Convention:** The number of leading underscores on a function name is a strong hint about its ordinality and intended use.

| Pattern                  | Example               | Usecase / Ordinality                                                     |
| :----------------------- | :-------------------- | :----------------------------------------------------------------------- |
| **Zero Underscores**     | `do_action`, `bookdb_add` | **High-Order**. Public, dispatchable function.                           |
| `_one_underscore`        | `_helper_function`    | **Mid-Ordinal**. A standard subroutine or helper.                        |
| `__two_underscores`      | `__literal_function`  | **Low-Ordinal**. A "close to the metal" function performing a raw task.    |
| `___three_underscores`   | `___desperate_case`   | Used sparingly, when desperate, for an even lower level of abstraction.    |
| `__TEMPLATE__`           | `__CONFIG_TPL__`      | A double-bound underscore denotes a template or sentinel value for substitution. |

-   **6. Guard Placement by Ordinality:** A **guard** is a conditional check that validates state or permissions before executing a piece of logic. The placement of guards is strictly determined by function ordinality.

| Guard / Mode         | Description                                                                 | Example Usage                                                  |
| :------------------- | :-------------------------------------------------------------------------- | :------------------------------------------------------------- |
| **`DEV_MODE`**       | A global mode enabling developer-specific logic.                              | `if is_dev; then dev_log "Running in dev mode"; fi`            |
| **`SAFE_MODE`**      | A global mode that can trigger extra safety checks, like automatic backups.   | `if is_safe_mode; then do_backup; fi`                          |
| **`__confirm_action`** | A high-order helper function that prompts the user for a yes/no confirmation. | `if __confirm_action "Delete all data?"; then rm -rf ...; fi` |
| **`is_*`**           | Generic guard functions that check a specific state (e.g., file existence).   | `if ! is_file "$path"; then fatal "File not found"; fi`        |

-   **7. Predictable Local Variables:** Every function **must** strictly adhere to the `Predictable Local Variables` paradigm (`ret`, `res`, `str`, `path`, `this`, etc.) as defined in **Part III, Section 3.0.1**.

-   **8. Readability & Visual Clarity:** Variable names and code structure should be legible and intuitive for visual thinkers and those with dyslexia.

-   **9. External Commands & Builtins Tracking:** At the top of each script, include a concise comment block listing external commands and Bash builtins used. This facilitates future portability analysis.
    
    **Example:**
    ```bash
    #!/usr/bin/env bash
    #
    # My Awesome Script
    #
    # portable: awk, sed, grep, curl, git
    # builtins: printf, read, local, declare, case, if, for, while
    #

    # ... rest of script
    ```

-   **10. String Templating:** Leverage string templates and helper functions (e.g., `printf -v`) to construct messages or content efficiently.

-   **11. Printing to File:** Any function that generates and writes content to a file **must** be contained within its own helper function, typically prefixed with `__print_`. Parameters should be passed positionally.

    **Example of Parameterized Printing:**
    ```bash
    # Low-ordinal helper function for printing
    # Arguments:
    #   1: file_path (string) - Destination file
    #   2: user_name (string) - User's name
    #   3: user_id (integer)   - User's ID
    __print_user_profile() {
        local path="$1";
        local name="$2";
        local id="$3";
        local content;

        printf -v content "USER_NAME=%s\nUSER_ID=%d\n" "$name" "$id";
        printf "%s" "$content" > "$path";
        return $?;
    }

    # High-ordinal dispatchable function
    function do_create_user_profile() {
        local dest_path="${XDG_DATA}/my_app/profile.conf";
        local current_user="Shebang";
        local current_id=777;

        # Call the print helper, mapping variables to positional args
        # Args: 1:path, 2:name, 3:id
        if __print_user_profile "$dest_path" "$current_user" "$current_id"; then
            okay "Profile written to %s" "$dest_path";
        else
            error "Failed to write profile.";
        fi;
    }
    ```

-   **12. Logic Guards & Reusability:** Create concise `is_` guard functions to avoid reimplementing complex logic blocks.

-   **13. Function Grouping:** Group similar functions together within the script.

-   **14. Commenting Functions:** Each major function **must** have a consistently formatted comment bar above it for readability.

    **Example:**
    ```bash
    ################################################################################
    #
    #  my_awesome_function
    #
    ################################################################################


    function my_awesome_function() {
        # ... function logic ...
    }
    ```
    -   Internal or partial helper functions (e.g., `_mix_batter`) can be grouped directly under their main parent function's comment bar for simple organization.
    -   Minor, standalone utility functions can be grouped under a common comment bar denoting their type.

-   **15. Identation:** Make sure that the inside body of a function is properly indented (as well as other blocks), for IDEs that have code folding; this is key for manual editing.



### **6.1 Examples**

These examples illustrate the application of BashFX coding style rules. They demonstrate preferred patterns (`GOOD`) and highlight common pitfalls (`BAD`). Please note there may have been some flux in these examples, they may not be entirely accurate, you can compare them against the rules and pillars as a quick test for yourself:

#### **6.1.1 Semicolon Usage & Block Termination**

Consistency and clarity in terminating commands and logic blocks.

```bash
# BAD: Missing semicolons, incorrect block termination
function bad_func() {
    if [ -n "$1" ]
    then; # bad: Sntax Error
        echo "Argument provided: $1"
    fi;  # bad: Sntax Error
    for i in {1..3}
    do
        echo "Loop iter: $i"
    done; # bad: Sntax Error 
} ; # Incorrect function termination and missing semicolons

# GOOD: Proper semicolon usage and block termination
function good_func() {
    local arg="$1"; # Semicolon for inline command
    if [ -n "$arg" ]; then # Semicolon after condition for inline 'then'
        stderr "Argument provided: $arg";
    fi # Proper 'if' block termination

    for i in {1..3}; do # Semicolon after loop header for inline 'do'
        stderr "Loop iter: $i";
    done # Proper 'for' block termination
} # Correct function termination
```

#### **6.1.2 Case Statements**

Patterns must be enclosed in parentheses.

```bash
# BAD: Missing parentheses for case patterns
case "$mode" in
    init)
        stderr "Initializing..." ;; # bad: Sntax Error
    start)
        stderr "Starting service..." ;;
    (act) stdrrr "Activate thing!" ;; # bad: Syntax Error on one liner, missing semicolon
    *)
        stderr "Unknown mode: $mode" ;;
esac

# GOOD: Correct parentheses for case patterns
case "$mode" in
    (init)
        stderr "Initializing...";
        ;; # Double semicolon for case pattern termination
    (start)
        stderr "Starting service...";
        ;;
    (act) stdrrr "Activate thing!"; ;; #one-liner termination
    (*)
        stderr "Unknown mode: $mode";
        ;;
esac
```

#### *6.1.3 Predictable Local Variables & Function Granularity (`_internal_name`, `___private_name`)**

Using standardized local variable names and breaking down complex tasks into smaller, organized functions.

```bash
# BAD: Overly long function, unclear variable names, no internal helpers
function process_data_long_name_bad() {
    local count_val=0;
    local temp_result="";
    # ... lots of complex logic ...
    for x_idx in $(seq 1 5); do
        if [ "$x_idx" -gt 2 ]; then
            count_val=$((count_val + 1));
            temp_result="${temp_result} processed:$x_idx";
        fi;
    done;
    if [ "$count_val" -gt 0 ]; then
        stderr "Processed count: $count_val. Final results: $temp_result";
    fi;
    return 0;
}

# GOOD: Modular, clear variable names, private helper function
################################################################################
#
#  ___process_data
#
################################################################################
# Description: Helper function to iterate and collect data for process_data_good.
# Arguments:
#   1: idx (integer) - Current index for processing.
#   2: count (nameref) - Name of variable to increment count.
#   3: str (nameref) - Name of variable to append result string.
# Returns: 0 on success (if condition met), 1 otherwise.
# Local Variables: idx, count, str
___process_data() {
    local idx="$1";
    local count="$2";    # Nameref for count
    local str="$3";  # Nameref for result string
    local ret=1; # Initialize return status

    if [ "$idx" -gt 2 ]; then
        count=$((count + 1));
        str="${str} processed:$idx";
        ret=0; # Success
    fi;
    return "$ret";
} # Correct function termination

################################################################################
#
#  process_data_good
#
################################################################################
# Description: Main function to process data using a private helper.
# Returns: 0 on success, 1 on failure.
# Local Variables: ret, count, res_str, i
function process_data_good() {
    local ret=1;     # Initialize return status
    local count=0;   # Predictable local variable for count
    local res=""; # Predictable local variable for result string

    local i; # Predictable local for iterator
    for i in {1..5}; do
        # Call the private helper function, passing variables by name for nameref
        ___process_data "$i" count res;
    done;

    # Final reporting logic
    if [ "$count" -gt 0 ]; then
        stderr "Processed count: $count. Final results: ${res}";
    fi;

    ret=0; # Overall success
    return "$ret";
} # Correct function termination
```




#### **6.1.4 Printing to File (`__print_` helper functions)**

Centralizing file content generation and writing.

```bash
# BAD: Inline heredoc for file content and direct printing
function create_config_bad() {
    local config_path="/tmp/myconfig.conf";
    local user_name="Shebang";
    local log_level="debug";

    cat << EOF > "$config_path"
# Config file for $user_name
LOG_LEVEL=$log_level
ENABLED=true
EOF
    stderr "Config written to: $config_path";
    return 0;
}

# GOOD: Dedicated __print_ helper with positional arguments and comments
################################################################################
#
#  __print_config
#
################################################################################
# Description: Generates and writes configuration content to a specified file.
# Arguments:
#   1: file (string) - Path to write the config file.
#   2: user (string) - User name for config header.
#   3: level (string) - Desired log level.
# Returns: 0 on success, 1 on failure.
# Local Variables: file, user, level, config_content
__print_config() {
    local file="$1";
    local user="$2";
    local level="$3";
    local ret=1; # Initialize return status

    printf -v config "%s\n%s\n%s\n" \
        "# Config file for ${user}" \
        "LOG_LEVEL=${level}" \
        "ENABLED=true";

    # Ensure the directory exists before writing
    mkdir -p "$(dirname "$file")";
    printf "%s" "$config" > "$file";
    ret="$?"; # Capture return status of printf
    return "$ret";
} # Correct function termination

################################################################################
#
#  create_config_good
#
################################################################################
# Description: Orchestrates creation of an application config file.
# Returns: 0 on success, 1 on failure.
# Local Variables: ret, config_dest, current_user, app_log_level
function create_config_good() {
    local ret=1;
    local dest="${XDG_ETC}/my_app/config.conf"; # Use XDG+ paths
    local user="$(whoami)";
    local level="info";

    # Call the print helper, mapping variables to positional args
    # Args: 1: file_path, 2: user_name, 3: log_level
    __print_config "$config_dest" "$current_user" "$app_log_level";
    if [ $? -eq 0 ]; then
        stderr "Config written to: ${config_dest}";
        ret=0;
    else
        error "Failed to write config to: ${config_dest}";
    fi;
    return "$ret";
} # Correct function termination
```



##### **6.1.5 Standard Stream Usage (`stderr`)**

All user/developer messages go to `stderr`; `stdout` is for capture.

```bash
# BAD: Mixing messages with stdout output
function get_version_bad(){
    echo "Checking version..."; # Message to stdout
    echo "1.0.0"; # Actual output to stdout
}

# GOOD: Messages to stderr, output to stdout
function get_version_good(){
    stderr "Checking version..."; # Message to stderr
    printf "%s\n" "1.0.0"; # Actual output to stdout
    return 0;
}

# Usage example to demonstrate separation
# bad_ver=$(get_version_bad) # Will capture "Checking version..." and "1.0.0"
# good_ver=$(get_version_good) # Will only capture "1.0.0", message goes to stderr
```



#### **6.2 Basic Script Structure**

This section outlines the standard organization and components expected within different types of BashFX scripts. The order presented reflects the general flow from top to bottom within a file.

##### **6.2.0 Component Definitions**

This lists and defines common structural components used across various BashFX script types.

**Framework**

**BashFX Framework** - is a full featured framework that includes dev tools, package management, a suite of libraries and modules, as well as well-defined patterns like escapes, printers, hooks, dispatchers, bootstrapping, advanced includes, advanced path resolution, and powerful utilities. As this still in development some patterns and tools are still emerging, while some historic patterns linger and are being refactored. As such it is considered alpha, but some functions and includes are used manually in MVP scripts. Generally when the architecture/guides mention includes or specific libraries its referring to assets from this framework. Most new MVP scripts and utilities, will manually copy key standard functions or implement key patterns or simple sets of functions that mimick the same signature footprint or use case for later integration. Stderr is big example of this. As of now the framework is housed in a repo called `fx-catalog` and is in a large state of flux with a handful of stable features. Important Note: As of today the BashFX Catalog scripts are being rolled out into their own repos rather than the monolith library.


**Script Types**

**Major Script (sometimes joking referred to as Legendary Scripts)** - is a fully featured set of tooling with a clear rewindable life cycle (install, setup, reset etc). They can be standalone or integrated with the BashFX Framework. Certain advanced features may not be available if the script is not using the framework. Major Scripts are considered complete if the featureset implements fully rewindable and symmetrical functions. CRUD is a standard baseline for most implementations, as well as installing to the XDG+ Lib location and linking itself to the XDG+ Bin location. These scripts will also keep track of state via their own rcfile and use other data/cache files following XDG+. 

**Utility Script** - is a standalone script, with generally a much smaller featureset than a Major. Typically, a utility will have one major baseline feature, and a handful of other support, small life cycle, and helper functions (but not necessarily, there is no clear limit to the main features it can support but a heavy dispatcher is usually a sign of a utlity script growing up). Usually they are composable via pipes and can implement a small dispatcher when the featureset calls for it. Utilities sometimes graduate into major scripts, when a need for a wider featureset arises, so its important the utilities are constructed for evolution. Utilies may also memoize or store information in rcfiles or data files, or add files to a local directory. `countx` utility for example creates a `.counter` file where its invoked and stores it counter files in a manifest `.count-manifest` in the users home. Utilities are manually installed and linked as they dont provide an installation interface. They can borrow functions from BashFX via being copied, but generally dont load any of the FX bootstrappers. They may also implement a driver to quickly test its feature assumptions.

**Library Script** - generally a library script will be created for use in the BashFX framework, but may be implemented independently in support of a Major Script or too offset reusabel code patterns that are likely to be provided by the framework later. They usually feature an explicit load guard or may use a load guard function from the framework, this prevents circular referencing. The script will set a var and alert the dev that it has been loaded to activate the load guard if its called again. Most library functions will have a similar namespace, but should not use the `do_` or `fx_` prefixes which are reserved. They can implement their own private/internal functions as needed.

**Test Script** - A script specifically designed to run tests for other BashFX components or external software. Usually invoked by the frameworks `driver` tool. Generally test scripts shouldnt try to alter the user environment, and instead hook into configurations 

**Key Script Sections**
Inclusive but not necessarily exhaustive, there may be outliers misisng from this list.

-   **shebang**: `#!/usr/bin/env bash` or `#!/bin/bash`. The interpreter directive.
-   **logo/figlet**: Optional ASCII art branding, typically a commented block at the top (see Part IV, 4.0 Embedded Docs - Logo Hack).
-   **meta**: Key-value pairs embedded in comments for script metadata (e.g., `# name: my_script`, `# version: 1.0.0`; see Part IV, 4.0 Embedded Docs - Meta Hack).
-   **portable**: A commented block listing external commands (e.g., `awk`, `sed`, `git`) and Bash builtins (e.g., `printf`, `read`) used by the script, facilitating portability analysis (see Part V, 5.0.7). 
-   **load guard**: For library scripts, a mechanism to prevent multiple sourcing (e.g., `if [ -z "$MYLIB_LOADED" ]; then MYLIB_LOADED=true; fi`).
-   **function plan**: As a pre-step to creating complex scripts, its helpful to create a comment list of all the functions you plan on implementing. This creates a mini todo list of sorts, but also provides a function reference. 
-   **readonly**: Global constants declared as `readonly` variables. These are usually self reference variables used for the script to operate on itself via identity parameters or provide namespacing like SELF_PID or SELF_SRC, SELF_PREFIX, SELF_NAME. However, note that SELF_ prefix is ephemeral and a script should use its own namespace to initialize these types of values. BOOK_PID, BOOK_PREFIX, are examples of this. Global readonly vars typical mark values that will not change during the scripts life cycle.
-   **config**: Variables defining configuration settings for the script or application, especially ones that can be overriden by a user or environment variable. with the exception of XDG+ compliant pathing or other fragile variables should be overridable. Its important to add a mechanism for switching the *base* XDG path from which the others are derived so that test suites, can properly mimick/virtualize an environment without being destructive. 
-   **bootstrap**: Initial setup, environment checks, and early-stage variable initialization.
-   **simple stderr**: Optional inclusion of minimal `stderr` functions if the full `stderr.sh` library is not sourced, to provide basic message output.
-   **includes**: Sourcing declarations for required external libraries, typically from `pkgs/inc/` when used withe BashFX framework. In script templates, an include/source invocation may phsyically insert file contents at the specific line banner;in this case the includes section listed here are the top-level includes that are not meant to be inserted.
-   **use_apps**: Initialization or setup for other BashFX applications, utilities or modules utilized by a larger script. Generally utilities communicate via composable pipes and not through the explicit use_app interface defined by the framework.
-   **vars**: Script-scoped or library-scoped variables. For a library sometimes this is a mechanism for introducing new variables into a larger scope.
-   **simple helpers**: Small, general utility functions, often using `_internal_name` prefix,  may also include guard functions like `is_empty`. In framework enabled libraries these are generally only permissible if a library does not already implement it.
-   **complex helpers**: Larger, more involved helper functions, often using `___private_name` prefix.
-   **api functions (dispatchable)**: Primary functions invoked by the `dispatch` mechanism (e.g., `do_action`, `fx_command`).
-   **setup functions**: Functions specifically for installation, uninstallation, or first-time setup logic.
-   **test helpers**: Specific functions for assertions, comparisons, and reporting within a test script.
-   **tests**: The actual test cases or test suite definitions.
-   **dispatch**: The command router, typically a `case` block, that directs control to `api functions` based on command-line input (see Part III, 3.0.5). A well-defined, dense dispatcher can be a sign of a mature script, and generally undesirable in a utility script. In this case, a utility script with a large dispatcher is a sign that its begging to be refactored into a full Major Script. Neglected utilities often exhibit these signs.
-   **usage**: The function that displays detailed help text to the user (see Part III, 3.0.5).
-   **options**: The argument parser function responsible for processing command-line flags (see Part III, 3.0.5).
-   **status**: A standlone function designed to communicate to the user or developer the state of related environment, varibles, files, etc in a clearly readable format.
-   **main**: The primary entrypoint function for the script, orchestrating its core lifecycle (see Part III, 3.0.5). Generally all initilazation, and awareness tests should be invoked from within main and not in the script body itself, the only exception to this is in smaller utility scripts that dont have a well defined dispatcher.
-   **driver**: A dedicated function or section for development-time testing and demonstration, typically invoked by `cmd driver [name]`. Major Scripts can implement a driver if its featurset surface is simple enough, otherwise an external test script is preferred. Standalone libraries *can* implement a local driver when bundled as a module, but it has to be properly namespaced. Generally library drivers should be deferred to the framework test suite.
-   **resolution**: only used in library scripts, sometimes state or properties need to be massaged in order to allow for proper sourcing/bundling of a library. The resolution segments adds a spot for such adjustments.
-   **load mark**: For library scripts, a marker/variable indicating successful loading (e.g., `echo "LIB_LOADED" >&2`).
-   **main invokation**: The final line that calls the `main` function to start script execution (e.g., `main "$@"`).

**Script General Templates**

Please note that these may not be precise or exhaustive, and may change over time. If you witness a script that deviates from this convention it may be old/legacy, partial state of being brought into compliance, or in need of refactoring. You may flag any scripts that fail this structural requirement.

Sections of code that may or may not used are denoted as optional, whereas the rest are generally considered to be required, but may be depenedent on unnoted use cases. Preferred section means a script is more architecutrally aligned if it uses this pattern but we leave room in case its not feasable at the time. MVP scripts will often eskew super alignment in favor of an MVP-grade alignment and denote what it is implementing and whether its full partial or none.

For scripts lacking a preferred or optional section, a comment bar can denote its absence.


##### **6.2.1 Major Script (aka Legendary Script)**

```bash
# shebang
# logo/figlet (preffered)
# meta
# portable 
# function plan
# readonly
# config
# bootstrap (preffered)
# simple stderr (optional)
# includes (preffered)
# use_apps (optional as needed)
# simple helpers (optional as needed)
# complex helpers (optional as needed)
# api functions 
# dev functions (optional)
# setup functions
# status
# dispatch
# usage
# options
# driver (optional**)
# main
# main invokation
```

##### **6.2.2 Utility Script**

```bash
# shebang
# logo/figlet (optional)
# meta
# portable
# function plan
# readonly (optional)
# config
# options (optional as needed)
# simple stderr (preffered)
# includes (optional)
# simple helpers
# status
# usage
# main
# driver (optional)
# main invokation
```
##### **6.2.3 Library Script**

```bash
# shebang
# meta
# portable
# load guard
# readonly
# vars
# lib functions
# resolution (optional)
# driver (sometimes)
# load mark
```

##### **6.2.4 Test Script**

```bash
# shebang
# meta
# portable
# readonly
# function plan
# vars
# simple stderr (optional)
# includes (optional)
# simple helpers (optional)
# complex helpers (optional)
# test helpers
# tests
# options (optional)
# dispatch (optional)
# usage
# main
# main invokation
```

##### **6.2.5 (NEW) Function Scripts**

A function file is a new type of script for isolated development and iteration of individual functions, the are usually named `func_name.func.sh`. They do not include a traditional bash shebang first line. And are used to stub out, iterate and correct functions without having to parse the entire code. These can be created manually or using the `func` tool if its available on `PATH`. Once a function is deemed complete it can be integrated back into the code at a designated comment marker. See the `func` usage docs or `ADM.md` for details.

```bash
# ! NO SHEBANG
# function ONLY
```

##### **6.2.6 Script Templates**

Not expanded upon here, but generally construct into one of the above types via an insertion and hydration mechanism.





