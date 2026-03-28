# Part III: The Standard Interface & Conventions

## 3.0 The Standard Interface

This section defines the core components of a BashFX script, from variable naming conventions to the required function skeleton.


## 3.1 Standard Variables

**Known Globals & Modes:** A concerted effort is made to respect community-accepted global variables (`DEBUG`, `NO_COLOR`). BashFX further defines these standardized modes, which act as high-level state toggles. Unless provided by a library or framework, they are generally regarded as implementation interfaces, and others may be implemented as needed.

| Mode         | Description                                                                                                                                                                                                                                                        |
| :----------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DEV_MODE`   | Enables developer-specific logic. The presence of this mode is often checked by `is_dev` or `is_user` **guard** functions. Guards are typically verb-like logic checks (e.g., `is_*`) that are often library-defined. If an application defines its own guards, it should follow the `is_` pattern to maintain library-compatibility, which also serves as a reminder to consider if they can be ported to a library. |
| `QUIET_MODE` | Disables most `stderr` messages.                                                                                                                                                                                                                                   |
| `DEBUG_MODE` | Toggles execution paths for diagnostics.                                                                                                                                                                                                                           |
| `TEST_MODE`  | Enables test-specific logic.                                                                                                                                                                                                                                       |

-   **Variable Case by Scope:**
    -   **ALL_CAPS_VARIABLES**: Represent one of two things: either a configuration value inherited from a session/setting file, or a pseudo-constant.
    -   **lowercase_variables**: Imply a more ephemeral, local scope (e.g., function arguments, local variables).
    -   **Example:** `OPT_DEBUG` and `opt_debug` may exist concurrently. `OPT_DEBUG` would be a framework-level or inherited setting, while `opt_debug` would be the function-local state variable derived from a command-line flag.


## 3.2 Standard Prefixes:

| Prefix        | Description                                                                                              |
| :------------ | :------------------------------------------------------------------------------------------------------- |
| `opt_`        | For argument flag states, typically set by the `options()` function.                                     |
| `dev_`        | For functions intended for internal testing or potentially destructive operations.                       |
| `fx_`/`FX_`   | **Reserved for the BashFX framework itself**, for package and dependency orchestration.                    |
| `fxi_`/`FXI_` | For the setup/installer context within the BashFX framework.                                             |
| `T_`          | Optional prefix for a temporary variable, explicitly marking it for a short lifecycle.                   |
| `T_this`/`THIS_`/`this_` | For the "Thisness" context pattern (see Part IV).                                              |
| `_name` / `__name` | Prefixes denoting pseudo-private helper functions, tied to Function Ordinality (see Part IV).        |
| `__NAME__`    | A double-bound underscore denotes a template or sentinel value.                                          |
| `____`        | The underbar blank often denotes a "poorman's this" or the immediate context.                            |


## 3.3  Predictable Local Variables ("Lazy" Naming):
 A predictable set of local variable names is consistently used for common tasks.
 > I'm lazy and naming things is hard.

| Category    | Variables        | Description                               |
| :---------- | :--------------- | :---------------------------------------- |
| Status      | `ret`, `res`     | Return status code, result/value          |
| Strings     | `str`, `msg`, `lbl`  | Generic strings, messages, labels       |
| Paths       | `src`, `dest`, `path` | Source, destination, generic path      |
| Iterables   | `arr`, `grp`, `list` | Arrays, groups, lists                   |
| Identity    | `this`, `that`, `ref`, `self` | References to objects or contexts     |
| Iterators   | `i`, `j`, `k`    | Loop counters                             |
| Spatial     | `x`, `y`, `z`    | Positional or coordinate markers        |
| Comparison  | `a`, `b`, `c`    | Variables for comparison or sets        |
| Logic       | `p`, `q`, `r`    | Grammatical or logical markers          |
| Cursors     | `curr`, `next`, `prev` | Pointers in loops or sequences        |
(New local variables should follow this paradigm where existing patterns are insufficient.)

## 3.4 Standard Functions

-   **Core Principles:**
    -   **Return Status:** Always return `1` (failure, implied default) or `0` (success, explicit).
    -   **Stream Usage:** `stderr` (`>&2`) is for human-readable messages. `stdout` is for machine-capturable data (`$(...)`).

-   **Function Naming (Public vs. Pseudo-Private):**
    -   **Public/Dispatchable:** Functions called by `dispatch` should be prefixed with `do_` or a script-specific vanity prefix (e.g., `bookdb_`).
    -   **Pseudo-Private:** Helper functions should be prefixed with `_` (mid-level) or `__` (low-level). See Part IV, Section 4.0 for a detailed explanation of Function Ordinality.

-   **Example Function Template:** This demonstrates the standard structure, including predictable local variables and explicit returns.
    ```bash
    function my_public_function() {
        local path="$1";
        local ret=1; # Default to failure
        local res="";  # For storing a result

        if _my_helper_is_valid "$path"; then
            res=$(__my_literal_get_data "$path");
            if [[ -n "$res" ]]; then
                ret=0; # Success
            fi;
        fi;
        
        printf "%s" "$res"; # Output result to stdout
        return "$ret";
    }
    ```
## 3.4.1 **Standard Function Roster:** 

A "Proper (Legendary) Script" is built from a predictable set of high-order functions.

| Function | Type        | Description                                                     |
| :------- | :---------- | :-------------------------------------------------------------- |
| `main()`    | Super-Ordinal | The primary entrypoint. Orchestrates the script's lifecycle.   |
| `options()` | Super-Ordinal | Resolves options and environment variables into opt_arguments  |
| `dispatch()`| Super-Ordinal | The command router. Executes `do_*` functions.                 |
| `status()`  | High-Order  | A ceremony indicating the state of the environment, data or application     |
| `logo()`    | High-Order  | Copies the figlet/logo block near the top of the script for vanity display  |
| `usage()`   | High-Order  | Displays detailed help text. Usually dispatched by a `do_help` function     |
| `version()` | High-Order  | Displays the vanity logo (if applicable), the script name and version, copyright and any license |
| `dev_*()`   | High-Order  | For development and testing. Must contain user-level guards.    |
| `is_*()`    | Guard       | Verb-like logic checks for validating state.                    |

*Important Note: For `version()` and `logo()`, these functions use `sed` to parse information directly from the script (as defined in the Embedded Doc Patterns in section 4 Experimental), for example logo will read the line numbers where the figlet is found in the script (Block Hack) , whereas version will read the embedded meta value `# version : 1.1.0` anywhere in the script file but usually at the top (Banner Hack). For logo this can be a problem if a very long script uses the `build.sh` pattern (in section 4 Advanced), which may insert automated comments and cause the actual final line numbers to shift.*

<br>

