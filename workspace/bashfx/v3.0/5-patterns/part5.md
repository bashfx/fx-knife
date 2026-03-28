# Part V: Architectural Patterns

### 5.0 Function Ordinality & The Call Stack Hierarchy

Function Ordinality defines a strict hierarchy for function types, establishing a predictable call stack and a clear separation of concerns. This model dictates where specific types of logic, especially error handling and user-level guards, should be implemented.

-   **High-Order vs. Low-Level Functions:** A fundamental distinction is made between functions that interact with the user and those that perform raw system tasks.
    -   **High-Order Functions (`do_*`, `dev_*`, `lib_*`):** These are orchestrators, composable entry points, or sub-dispatchers. They are responsible for interpreting user intent, managing the workflow, and applying user-level guards.
    -   **Low-Level Functions (`_*`, `__*`):** These are "close to the metal" helpers that perform a single, literal job. They trust their inputs and are only responsible for guarding against system-level errors (e.g., a file not being writable).

-   **System-Level vs. User-Level Errors:**
    -   **System-Level Errors:** Defects that cause the system to fail regardless of user input.
    -   **User-Level Errors:** Undesirable states caused by user input. The responsibility for preventing these lies exclusively with High-Order functions.

-   **The Ordinal Hierarchy:** The following table illustrates the typical call stack and defines the function types within it.

| Ordinality | Function Type        | Example Name(s)         | Typical Call Path / Usage                                      |
| :--------- | :------------------- | :---------------------- | :------------------------------------------------------------- |
| **Entry**  | Script Entrypoint    | `(script execution)`    | `main "$@"`                                                    |
| **Super**  | Core Orchestrator    | `main`, `dispatch`      | `main` calls `dispatch` to route commands.                     |
| **High**   | Independent Function | `options`, `install`, `usage` | `main` -> `options`. Does not depend on runtime state.          |
| **High**   | Dispatchable Function| `do_action`, `bookdb_add` | `dispatch` -> `do_action`. The primary entry point for user commands. |
| **Mid**    | Subroutine / Helper  | `_validate_input`     | `do_action` -> `_validate_input`. Breaks down complex logic.  |
| **Low**    | Literal Function     | `__write_to_file`     | `_validate_input` -> `__write_to_file`. Performs a single, raw task. |

-   **How Ordinality is Determined:** A function's position in the call stack, not just its name, determines its ordinality. A prefix is a hint, but the execution path is the truth.
    -   The key determinant is **dispatchability**. Any function directly callable by `dispatch` (e.g., `do_*` or a vanity-prefixed function) is considered **High-Order**. Any function called by a High-Order function is, by definition, of a lower ordinality.
    -   **Library functions** (`lib_*` or other vanity prefixes) are not inherently low-level. If a dispatcher calls a library function directly, that function is High-Order for that specific execution and is responsible for any necessary user-level guards. If it's called by another `do_*` function, it is acting as a lower-ordinality helper.

-   **Independent Functions:** A special class of high-order functions (like `options()` or administrative commands like `install` and `reset`) that can be called by `main` *before* `dispatch`.
    -   These functions must not depend on any application state that would normally be set up for a dispatchable command. For example, they cannot assume a configuration file has been loaded or a database connection is active.
    -   They are **prohibited from calling dispatchable (`do_*`) functions** precisely because those functions *do* depend on that runtime state.
    -   Simple utility scripts often consist entirely of independent functions, as they may not track state.
    -   The `usage` function is typically independent. However, if a script requires `usage` to display dynamic, state-dependent information (e.g., a list of available items from a database), a separate `status` or `dashboard` command should be created as a dispatchable function instead. This keeps `usage` clean and state-independent.

-   **Why Ordinality Matters: A Framework for Predictable Flow**
    Function Ordinality is a meta-pattern that provides a predictable, structured flow for the entire application. It defines an implied call stack, ensuring that logic is placed at the appropriate level of abstraction. This structure is critical for several reasons:
    -   **Maintainability:** By knowing a function's ordinality, a developer immediately understands its purpose, its allowed dependencies, and where to find the relevant user-level guards. It prevents "spaghetti code" where low-level functions make high-level decisions.
    -   **Testability:** High-order functions can be tested by simulating user input, while low-level functions can be unit-tested with known good data, as they don't need to handle user error.
    -   **Security & Safety:** It enforces the principle that all user input is sanitized and validated at the highest possible level before being passed down to "literal" functions that perform potentially destructive actions. A `__write_to_file` function should never have to worry about what's in the string it's writing; that's the job of the `do_save_data` function that called it.

-   **Enforceability**
    The ordinal rules provide a structure/framework for how to organize code and what scope to implement certain patterns. There is no checker, linter or validator (yet), instead these are principles and standards to be followed to help ensure that code is easier to understand, with a clear path of execution, and contextual hints towards good practices.

### 5.1 Standard Patterns

-   **Proper Script**: A fully self-contained script that implements the BashFX Standard Interface (set of functions), and supports the Standard Patterns (especially XDG+), as needed. As the library and standard patterns are further cleaned up, the definition of proper script may expand. "Proper" here implying that a script is fully featured and compatible with the BashFX framework.

-   **Dynamic Pathing**: Most pathing invocations start from a relative root usually `$SOMETHING_ROOT` or `$SOMETHING_HOME`, from which all other subpaths derive. This is in line with BashFX's principle of self-containment because it contains everything downstream. Historically most paths have been relative to `$HOME`, but are now using the `XDG` root which is `~/.local`.

-   **RC Files**: BashFX uses rcfiles (`*.rc`) to indicate state or demark a session.
-   **Stateful**: Rcfiles are treated as mini sub-profiles that switch a user into a branched sub-session by setting certain environment variables, defining aliases and functions, or writing other state files. The presence or lack of an rcfile indicates a start or end state respectively, and any set of variables within the rcfile can indicate other interstitial states.
-   **Linking**: Rather than writing data directly to a user's `.profile`, BashFX uses a linking system (`link`, `unlink`, `haslink`) via `sed` or `awk` to link its master rcfile (`.fxrc`); any additional linking by its packaged scripts can treat `.fxrc` as the master session and be enabled (`link`) or disabled (`unlink`) simply by removing their link lines, usually indicated by a label.
-   **Canonical Hook**: Early versions of BashFX relied on finding canonical profiles in order to add sentinels and environment loaders, but has since switched to using the `.basrhc` file as the primary entry point for environment confiruation. Newer versions of BashRC's profile specification (undocumented) further provide an explicity hook file `XDG_RC_HOOK_FILE` for any script that wishes to auto-load its environment configurations as part of a user's profile boot routine. Using Bashrc allows the user to refresh their settings if the hook file changes. The hook file would be the place you would add any sort of banner or flag loading an external rc file for your scripts and tools.

-   **XDG Variables for Awareness**: Scripts should use `XDG_*` variables for startup and system awareness, ensuring they place files in predictable, user-approved locations.

### 5.2 Bash Hack Patterns (BHP)

- **Sentinels: Markers of Ownership & State:** A sentinel is a unique marker or string delimiter used to indicate ownership, state, or a location for automated processing. They are the backbone of rewindable operations and allow scripts to modify files without corrupting them.
    -   **Flag/Tag:** A comment on the same line as code (e.g., `source file.sh # My Sentinel`). Used for line-based linking and unlinking.
    -   **Banner:** A full line that is itself a sentinel (e.g., `#### my_banner ####`).
    -   **Block:** A section of code or text enclosed by banner-style sentinels.
    -   **File Sentinels:** The presence of a file itself (e.g., a `.rc` file or a cursor file) can act as a sentinel, indicating a specific application or session state.

-   **Embedded Docs ("Comment Hacks"):** This powerful but potentially brittle pattern uses sentinels to embed documentation, templates, and other metadata directly within a script's comments. As comments, these sections are out-of-scope unless activating scripts are applied to them. While useful for self-contained tools, its reliance on specific `sed`/`awk` parsing can be fragile and is considered an advanced technique rather than a baseline standard.
    -   **Some variants:**
        *   **Logo Hack** - In a proper script, commented lines under the shebang often feature some sort of branding or ASCII art. The line numbers are globbed and the comment prefix stripped and later printed to screen as an intro.
        -   **Meta Hack**  - Key-value pairs embedded in a comment like `# key: value`, used for things like naming, versioning, and other meta-data.
        -   **Flag Hack**   - Marking a line for insertion via a comment sentinel that has the effect of embdedding another document inside at the sentinel.
        -   **Banner Hack** - Marking a line for editing by appending a comment to the end of a bash statement with a unique sentinel.
        -   **Block Hack**  - A sentinel-bound scriplet, usually used to print the `usage()` documentation or the state saving rcfile. This method is preferred for `usage` blocks over heredocs due to indentation flexibility. Block sentinels usually look like ` #### label ####` or have an HTML-like open and close tag.
        -   **Document Hack** - An entire document embdedded in a script comments, usually the usage/help message, but can include other templates. The doc content is usually marked with a block sentinel something like "##!doc:name##". 

-   **Thisness:** This experimental pattern uses a set of `THIS_*` prefixed variables to simulate instance-specific scope for generalized library functions. A mainline script can call its own `[namespace]_this_context` to define these variables for use in shared library scripts. This enables a higher degree of code reuse, as well-defined functions don't have to be included every time just to accommodate a different namespace. Using thisness is only ideal in a single script context, where `THIS_*` values are unlikely to be clobbered.


### 5.3 Advanced Patterns

The BashFX ecosystem leverages some of its own tooling to build and manage legendary scripts; as more of these tools mature and defects resolved they get baked back into other scripts. One example of this is `semv` which is a tool for managing versions in relation to git commit labels, and meta values provided by a script (though this is still being worked on at the moment). Three(Two) other mature integation patterns have emerged as part of a typical BashFX workflow you can now consider. (Below: Build.sh, Padlock, GitSim)


### 5.3.1 The Build.sh Pattern v1

To manage super long Bash scripts (usually anything more than 1000 lines), the `build.sh` pattern should be used. Script are broken into part files in a `.\parts` directory along with a `build.map` file that maps a number `03` to a file like `03_stderr.sh` that is needed to generate the final output. The build script is smart in that any file placed in part that does not match the official part name will be used to update the part file if it has the correct number prefix; this smart synching is mostly to support manual mode where the code is being generated external from the repo.

```bash
#example build.map

# Build Map  
# Format: NN : target_filename.sh
# Lines starting with # are ignored
# Place this file in: parts/build.map

01 : 01_header.sh
02 : 02_config.sh  
03 : 03_stderr.sh
04 : 04_helpers.sh
05 : 05_printers.sh
06 : 06_api.sh
07 : 07_core.sh
08 : 08_main.sh
09 : 09_footer.sh
```

In version 1 of this pattern, the build.sh script is provided manually, and must be updated with the correct settings like the `OUTPUT_FILE` which designate the final file to be built. The presence of `build.sh` or a `/parts` likely indicates the target or flagship script is generated by build.sh and should not be edited directly, instead the individual part files should be created/edited instead. If more part files are needed the `build.map` file can easily be extended to help breakdown large complex script sections into smaller manageable pieces. 

Generally a script part more than 300-500 lines is too big and should be broken down. Note that script parts must terminate on a full function (no split code), and only the initial part 00 should have the shebang line.

**Script Complexity and Porting:** Build.sh pattern attempts to balance the tension between scripts getting too large, and scripts being simple enough to be a Bash implementation. This tension however is not without limits; as a script approaches 3000-4000 lines of code, this creates an absolute tension where additional features are typically not desired. Instead, such Legendary Scripts at this scale will be designated for porting to Rust via the REBEL/RSB Architecture (Rebel String Biased Architecture) and the RSB DSL which provides a library of macros, functions and patterns to create a bash-like interface in rust. Another version of the RSB approach is where mature Legendary BashFX Scripts are provided as "Community Editions" to a more "Professional Edition" implemented in RSB. This RSB note will only be relevant if you are working on a port from BashFX to Rebel/RSB.


### 5.3.2 The Padlock Pattern v1

Without getting too deep into the weeds on this, the `padlock` scripts allows for encryption of secure documents, private ip, keys, and other secrets using the `age` encryption tool/algorithim. Its powerful multiple key system allows for novel patterns of security. When a BashFX repo is using padlock, evidence of it is seen through the presence of `.chest/` directory, `.age` files, `locker/` directory or potentially a `padlock.map` file. A master key is stored for recovery for all repos leveraging a systems local padlock install, but each repo will also have its own secure key. Git hooks are employed to automatically hide and restore secrets as part of the clone and checkout process; however the lock and unlock commands can do this without hooks. This pattern is in alpha-v1 mode, meaning it does mostly work but there may be some errors with it still. It's acceptible to back files into a tar/zip locally before attempting to secure them, while padlock is still in alpha. 

### 5.3.3 The GitSim Pattern v1

Many BashFX scripts and even other Rust/RSB tools rely on re-creating environment conditions like a home folder or a project folder; `gitsim` creates virtual sandboxes for tools that need to test for presence of `.git` or `.bashrc` or other standard files and directories. When gitsim is run in a project folder it creates a `.gitsim` folder where all of its artifacts are generated, alternatively if a home sandbox is created it usually puts them in the XDG+ cache `$HOME/.cache/tmp`, and uses the XDG+ HOME `XDG_HOME` instead of trying to override the users `$HOME` as part of the XDG+ Home Policy. Gitsim is a simple yet powerful tool, and is ever expanding with new features use the `gitsim help` command to see what it is capable of. Using gitsim is generally preferred to writing your own pre-test harness and pseudo environments, as a more standardized solution for test suites and smoke tests.

### 5.3.4 Func Tool

Mentioned here briefly for completeness, the `func` tool is a powerful script for analyzing,comparing and editing shell functions within a file. the `func ls <src>` prints all functions, `func spy <name> <src>` prints the function contents, and others. See `func help` for its current command surface. 


