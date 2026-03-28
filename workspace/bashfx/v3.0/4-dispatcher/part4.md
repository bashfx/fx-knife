# Part IV: Standard Dispatcher Conventions 

## 4.0 The Standard CLI Pattern

This section defines standardized patterns for designing command-line interfaces in complex (legendary) FX applications. These conventions build upon the existing Options pattern and introduce architectural patterns for managing CLI complexity as tools mature. While FX defines this opinoinated pattern, it can apply to any CLI tool, and is not bash-specific.



**Note on Examples:** This section uses `padlock` commands extensively to demonstrate CLI patterns because padlock represents a sophisticated multi-entity system that clearly illustrates the architectural challenges these patterns solve. However, **these patterns should be evaluated and applied as needed** when designing the command surface for any BashFX application. The specific commands are less important than understanding when and why to apply each pattern.

Other tools will face analogous challenges:

* Package managers operating on packages, repositories, and configurations
* Build systems managing projects, targets, and dependencies
* Network tools handling connections, interfaces, and policies
* File management tools working with files, directories, and permissions

The patterns described here provide architectural solutions for any CLI that grows beyond simple single-entity operations.

## 4.1 Command Surface
The **command surface** is the complete dictionary of ALL user-input combinations that produce actions/outputs through the entire dispatcher hierarchy. This includes:

- **Main commands**: `padlock clamp`, `padlock lock`
- **Sub-commands**: `padlock master generate`, `padlock ignite create`  
- **Arguments**: `padlock ignite create ai-bot` (positional args)
- **Options**: `padlock clamp /repo --force` (flags and values)
- **Predicates**: `padlock rotate master`, `padlock key is skull`
- **Complex combinations**: `padlock ignite create ai-bot --phrase="secret" --force`

**Critical for Porting**: When porting from FX to RSB, the **entire command surface must remain identical**. Every command/option/flag combination that works in the Bash version must work exactly the same way in the RSB version.

**Not Part of Command Surface**: Internal function names, implementation details, or code organization - these can change during porting as long as the external interface remains identical.


## 4.1.2 Sub Command Dispatchers

First let's consider the following:

### The Command Specificity Problem; an example 
The `padlock` command is a very powerful security tool. This `rotate` command has the effect of invalidating a key as well as its child keys in its authority chain. However what is wrong with this command?
```bash
# seemingly harmless command
padlock rotate;
```
Does this rotate a specific key, which key? All keys, the master key? the current folder key? Who knows. This command was implemented (incorrectly) in live production-ready code. 

Let's say that this did rotate either all keys or the master key... that would be completely disasterous! every key in the security architecture would be invalidated corrupting the entire system. The fact that we dont know which key this is applying to is the exact problem a sub dispatcher resolves.

```bash
# ah much better we're only rotating the lower authority distro key
padlock rotate distro;
```

### An Anti Pattern.


An alternative to this approach is to use commands that `look-like-this`; while the hyphenated approach has its (limited) uses cases, it creates complexities in a system designed to treat hyphens as primarily a flag/option artifact (see *the Standard Options* section). 

```bash
# ugly but solves command specifity
padlock rotate-distro;
```


This ugly command style often appears as a poor-man's attempt to solve a uniqueness problem within a rich, collision-prone command surface (e.g. "naming things is hard"). However, this is code smell for a CLI, especially if the command surface is sparse.

As an alternative, the FX Dispatcher Pattern standardizes a more elegant approach: the scoped and predicated sub-dispatchers.

This fundamental architectural distinction between scope and predicate emerges from developing sophisticated CLI tools and addresses a critical design decision: **when to group operations under entity scopes vs when to use cross-entity predicates**.

## 4.2 Scope-Specific Dispatcher (Scoped Commands)

**Pattern**: `<scope> <operation> [<args...>]` where the operation only exists within that entity's conceptual scope.

```bash
# Operations that are conceptually tied to a single entity type
padlock master generate   # "generate" only makes sense for master keys
padlock master show       # "show" here means "show master key details"
padlock master restore    # "restore" here means "restore from master backup"
```

**Key Insight**: These operations are **entity-specific implementations** that cannot meaningfully apply to other entity types. You cannot "generate" an ignition key the same way you generate a master key - they are fundamentally different processes.

## 4.3 Predicate-Specific Dispatcher (Predicate Commands)

**Pattern**: `<operation> [<entity args...> ]` where the same operation conceptually applies across multiple entity types. Here entity is actually an anchored argument (first position). Predicates mimick natural language.

```bash
# Same conceptual operation across different entity types
# another way to look at this is that rotate is the command and after it the input
padlock rotate master     # rotate the master key
padlock rotate ignition   # Invalidate + regenerate ignition key  
padlock rotate distro     # Invalidate + regenerate distributed key
padlock rotate            # invalid because lacks specificity. Subdispatcher can reject this.
```

**Key Insight**: These operations represent the **same fundamental algorithm** applied to different targets. The `rotate` process from `padlock` (invalidate old → generate new → update references) is conceptually identical regardless of entity type.

## 4.3.1 Why Not Put Everything Under Scopes?

This examples shows an inversion of the `rotate` command acting as a *scope*-dispatcher, instead of its more natural *predicate*-dispatcher. 

**Tempting but Wrong**:
```bash
# this doesnt work because master is not a command, its the argument
padlock master rotate     # Rotation logic in master scope
padlock ignition rotate   # Duplicate rotation logic in ignition scope
padlock distro rotate     # Duplicate rotation logic in distro scope
```

**Problems with Using Predicates as Entity-Scoped Operations**:

1. **Code Duplication**: Same rotation algorithm implemented multiple times
2. **Behavioral Inconsistency**: Each entity scope might implement rotation differently
3. **Maintenance Complexity**: Bug fixes and features need multiple implementations  
4. **Poor Discoverability**: Users must learn which entity scopes contain which operations
5. **Conceptual Confusion**: Operations that work the same way appear different


So fundamentally, while the two approaches may look indisintguishable on the surface, the patterns are intentional in how they are structured in the dispatcher implementations. This anti-pattern becomes more apparent with familiar commands like `ls`

**Correct Predicate Pattern**: Here padlock has adapted an internal `ls` predicate command to mean list items
```bash
padlock ls master     # list master keys (should only be one)
padlock ls distro     # list all distro keys 
padlock ls ignition   # list ignition keys

#the actual ls command looks weird when inverted, this illustrates the scope problem, 
# what is the command and what is the argument?
> $HOME/path ls
```


**Correct Architecture**:
```bash
# Single implementation, multiple targets
padlock rotate master     # Same rotate() function, master-specific handling
padlock rotate ignition   # Same rotate() function, ignition-specific handling
padlock rotate distro     # Same rotate() function, distro-specific handling
```

## 4.2 CLI Pattern Decision Framework

### 1. Single Entity Context (Direct Commands)
**When to use**: Operations on implicit entities or obvious context.

```bash
# Current context is obvious
tool build         # Build current project
tool status        # Status of current context
tool clean         # Clean current workspace
```

### 2. Entity-Specific Operations (Mini-Dispatchers) 
**When to use**: 3+ operations that only exist within one entity's conceptual scope.

```bash
# Operations unique to master keys
padlock master generate   # Only masters can be "generated" this way
padlock master show       # Show master-specific information
padlock master restore    # Restore from master-specific backup
padlock master unlock     # Unlock master-specific encryption
```

**Implementation Pattern**:
```bash
do_master() {
    local action="${1:-help}"
    shift || true
    
    case "$action" in
        generate) do_master_generate "$@" ;;
        show) do_master_show "$@" ;;
        restore) do_master_restore "$@" ;;
        unlock) do_master_unlock "$@" ;;
        help|"") help_master ;;
        *)
            erro "Unknown master action: $action"
            erro "Available: generate, show, restore, unlock"
            return 1
            ;;
    esac
}
```

### 3. Cross-Entity Operations (Predicate Commands)
**When to use**: Same conceptual operation applies to multiple entity types.

```bash
# Same operation, different targets  
tool rotate master        # Cross-entity rotation operation
tool rotate project       # Same rotation concept, different target
tool list repos          # Cross-entity listing with filter predicate
tool list projects       # Same listing concept, different filter
```

**Implementation Pattern**:
```bash
do_rotate() {
    local entity_type="$1"
    local entity_name="${2:-}"
    
    case "$entity_type" in
        master)
            _rotate_master_implementation
            ;;
        project)
            _rotate_project_implementation "$entity_name"
            ;;
        *)
            erro "Cannot rotate '$entity_type'"
            erro "Available targets: master, project"
            return 1
            ;;
    esac
}
```

### 4. Path Disambiguation (Options Pattern Extension)
**When to use**: Paths or ambiguous strings need clarification.

```bash
# Ambiguous without context
tool check config         # Is "config" a type or filename?

# Disambiguated with options
tool check --file=config  # Clearly a file path
tool config check         # Clearly entity + operation
```

## Integration with Existing BashFX Patterns

### Enhanced Options Pattern

The existing BashFX Options pattern handles flags and modifiers. CLI Conventions extend this for disambiguation:

**Traditional Options** (modifiers):
```bash
tool create project --force --template=basic
```

**CLI Conventions Options** (clarifiers):
```bash  
tool verify access --key=/ambiguous/path --repo=/another/path
tool check integrity --target=/could/be/anything
```

**Implementation**:
```bash
# Parse both modifier and clarifier options
local opts=("$@")
local force=false key_path="" repo_path=""

for ((i=0; i<${#opts[@]}; i++)); do
    case "${opts[i]}" in
        --force)                    # Modifier option
            force=true
            ;;
        --key=*)                    # Clarifier option
            key_path="${opts[i]#*=}"
            ;;
        --repo=*)                   # Clarifier option  
            repo_path="${opts[i]#*=}"
            ;;
    esac
done
```

### Dispatcher Pattern Evolution

**Simple Dispatcher** (early BashFX):
```bash
dispatch() {
    case "$1" in
        build) do_build ;;
        test) do_test ;;
        clean) do_clean ;;
    esac
}
```

**Mature CLI Dispatcher** (with conventions):
```bash
dispatch() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        # Direct commands (single entity context)
        build) do_build "$@" ;;
        status) do_status "$@" ;;
        
        # Mini-dispatchers (entity-specific operations)
        master) do_master "$@" ;;
        config) do_config "$@" ;;
        
        # Cross-entity operations (predicate commands)
        rotate) do_rotate "$@" ;;
        list) do_list "$@" ;;
        
        # System commands
        help) do_help "$@" ;;
        *)
            erro "Unknown command: $cmd"
            usage_simplified
            return 1
            ;;
    esac
}
```

## Help System Architecture

### Tiered Help for Token Economy

**Simplified Help** (~50 tokens, AI-optimized):
```bash
usage_simplified() {
    echo "Commands: build, deploy, config, rotate, list"
    echo "Mini-dispatchers: master (generate|show), config (edit|validate)"  
    echo "Help: tool help <command> or tool help more"
}
```

**Contextual Help** (~100 tokens, task-focused):
```bash
help_master() {
    echo "Master Key Operations (entity-specific):"
    echo "  tool master generate     Create new master key"
    echo "  tool master show         Display public key"  
    echo "  tool master restore      Restore from backup"
    echo ""
    echo "Cross-entity operations:"
    echo "  tool rotate master       Rotate master key"
    echo "  tool list masters        List master keys"
}
```

**Detailed Help** (~500+ tokens, field reference):
```bash
usage_detailed() {
    # Comprehensive documentation with examples, environment variables,
    # edge cases, troubleshooting, and complete option listings
}
```

### Contextual Help Implementation

Support both help patterns:
```bash
# Both of these work:
tool help master     → help_master()
tool master help     → help_master()

do_help() {
    local topic="${1:-}"
    case "$topic" in
        master) help_master ;;
        config) help_config ;;
        more) usage_detailed ;;
        "") usage_simplified ;;
        *)
            erro "No help for: $topic"
            usage_simplified
            ;;
    esac
}
```

## Anti-Patterns and Pitfalls

### 1. Scope Confusion
```bash
# ❌ WRONG: Cross-entity operation in entity scope
tool master rotate    # Should be: tool rotate master

# ❌ WRONG: Entity-specific operation as cross-entity  
tool generate master  # Should be: tool master generate
```

### 2. Hyphenated Commands (Discouraged)
```bash
# ❌ AVOID: Poor UX and no architectural benefits
tool deep-scan
tool auto-fix
tool pre-validate

# ✅ BETTER: Use appropriate patterns
tool scan --deep          # Direct command + modifier
tool maintenance auto     # Mini-dispatcher if 3+ "maintenance" operations
tool validate --pre       # Direct command + modifier
```

**Exception**: <1% of cases where no natural grouping exists and it's truly a one-off specialized operation.

### 3. Flag-Heavy Interfaces
```bash
# ❌ WRONG: Flags for core functionality
tool --action=rotate --target=master --force

# ✅ CORRECT: Natural language with minimal flags
tool rotate master --force
```

## Implementation Benefits

### Scalability
- **Start Simple**: Direct commands for basic functionality
- **Add Predicates**: When operations apply to multiple entities
- **Create Mini-Dispatchers**: When entity-specific operations cluster
- **Use Options**: For disambiguation and modifiers

### Safety
- **Explicit Targeting**: `tool rotate master` prevents accidental operations
- **Entity Boundaries**: Clear separation of concerns
- **Validation**: Predicate enforcement catches invalid targets

### Maintainability  
- **Single Implementation**: Cross-entity operations avoid duplication
- **Consistent Patterns**: Users learn one set of conventions
- **Extensible**: New entities fit existing patterns
- **Testable**: Clear function boundaries enable focused testing

### User Experience
- **Natural Language**: Commands read intuitively
- **Contextual Help**: Focused assistance when needed
- **Token Efficiency**: AI interactions optimized
- **Progressive Disclosure**: Complexity revealed as needed

These CLI conventions transform complex tools from "flag soup" into intuitive, maintainable interfaces that scale gracefully with application sophistication while preserving the simplicity of direct commands where appropriate.

## 4.3 Options & Argument Parsing

-   **`options()`:** This function is solely responsible for parsing command-line flags and setting `opt_*` state variables. It is considered an "independent" function, callable by `main` before any state-dependent logic.

-   **Standard Flags & Behavior:**

| Flag      | Variable      | Description                                                                 |
| :-------- | :------------ | :-------------------------------------------------------------------------- |
| `-d`      | `opt_debug`   | Enables first-level verbose messages (`info`, `warn`, `okay`).              |
| `-t`      | `opt_trace`   | Enables second-level messages (`trace`, `think`); often enables `-d` as well. |
| `-q`      | `opt_quiet`   | Silences all output except `error` and `fatal`. Overrides other log flags. |
| `-f`      | `opt_force`   | Bypasses safety guards or non-critical error checks.                      |
| `-y`      | `opt_yes`     | Automatically answers "yes" to all user confirmation prompts.               |
| `-D`      | `opt_dev`     | A master developer flag, often enabling other flags like `-d` and `-t`.     |

-   **Notes on Implementation:**
    -   Current implementations do not support combo flags like `-df` and avoid external parsers like `argparse`. Instead, capital case flags can be used to flip multiple other flags, as in the case of `-D`.
    -   BashFX's logging libraries standardize the following assumptions:
        -   **Semi-Quiet by Default:** If no logging flag is set by `options()`, only `error` and `fatal` messages are visible. The minimal `-d` flag is required to see first-level output (`info`, etc.), and `-t` for second-level.
        -   **Forced Output:** `-f` can override an inherited quiet mode.
        -   **Dev Mode:** The `-D` flag is used in conjunction with `dev_*` functions and `dev_required` guards to enable developer-specific output.

### 4.3.1 Standard Options Implementation

BashFX options parsing system is pretty clean yet simple, to start you must initialize any options you need to support in the beginning of your script, this allows them to be accessed globaly by functions that need them; all options should start with `opt_`.

A. Resolution. Option/Env Variable resolution. The `options` function provides the surface for resolving environment variables like `DEBUG_MODE` with user provided options like `-d`; generally the user provided options have precedent over environment ones except in rare cases. The `options` implementation uses a simple for loop and the resolution happens in case block. 

B. Option Arguments Pattern. This function can also be used to support option arguments in the form `--flag=value` or `--file=path` or `--multi=val1,val2,val3`. You are generally advised to use this `=` pattern so that the command dispatcher doesnt confuse arugment options for commands.

```bash

  options(){
    local this next opts=("${@}");
    for ((i=0; i<${#opts[@]}; i++)); do
      this=${opts[i]}
      next=${opts[i+1]}
      case "$this" in
        --debug|-d)
          opt_debug=0
          opt_quiet=1
          ;;
					# ... others
        *)    
          :
          ;;
      esac
    done
  }

```

C. Finally in the bottom of your script where main is called, the options invoker also has a trick to remove all flag-like options in the arguments array:

```bash

# then before main is called I have


  if [ "$0" = "-bash" ]; then
    :
  else
		# direct call
    orig_args=("${@}")
    options "${orig_args[@]}";
    args=( "${orig_args[@]/^-*}" ); #delete anything that looks like an option
    main "${args[@]}";ret=$?
  fi

```

Using the standard options patterns keep things organized and simple.

## 4.4 Printing & Output Conventions

A core tenet of of BashFX's Friendliness principle is "Visual Friendliness", which arises out of a need for terminal to have better UX for dyslexic folks and visual spatial thinkers who may prefer gui, images, and other hints for mental modeling. BashFX provides numerous features and patterns with this goal in mind, and updates them frequently.


This section governs all human-readable output:

-   **Output UX:** A suite of standardized printing utilities (`stderr.sh`, `escape.sh`) provides a simple `stderr()` function, a suite of log-level like functions wrapping the stderr stream via printf, and other UX visualization like borders lines and boxes, and confirmation prompts. *escape.sh* features a curated set of 256-color escape codes and glyphs for use with the various printer symbology. Note these are not standard structured log-levels, but BashFX UX-friendly log levels. 

    - Baseline (default level) aka  aka QUIET(0), cannot be silenced.
        - *error* - (red) a function guard was triggered or resulted in an invalid state.
        - *fatal* - (red) similar to error but calls exit 1 for unrecoverable errors.
        - *stderr* - (no color) basic log message no color or glyphs. 
            
    - Standard Set (first level `-d opt_debug`) aka QUIET(1)
        - *warn* - (orange) imperfect state but trivial or auto recoverable.
        - *info* - (blue) usually a sub-state change message. (this may also be used to indicate a stub or noop)
        - *okay* - (green) main path success message, or acceptible state.

    - Extended Set (second level `-t opt_trace`) aka  aka QUIET(2)
        - *trace* - (grey) for tracing state progressing or function output
        - *think* - (white) for tracing function calls only
        - *silly* - (purple) for ridiculous log flagging and dumping of files when things arent working as expected. (a variation of this is *magic*) This may be used for "invalid" conditions as well.
            
    - Dev Mode Set (fourth level `-D`)
        - *dev* - (bright red) dev only messages used in conjuction with `dev_required()` guards.

    - Additional custom loggers can be gated by the level-specific option flag.    
    - The first level and above follow typical loglevel usage, but currently only supports on/off gating with opt_debug and opt_quiet. Error messages can never be silenced.
    - The second level and above set must be enabled explicitly, via `opt_trace`, `opt_silly` and `opt_dev`. 
    - All of the loglevel messages are colored with a glyph prefix. If no styling is desired use the `stderr()`
        
-   **Non-Optional Printers:**  Important Note: many BashFX scripts rely on the stderr printers to generate user messages, however if not implemented correctly can lead to conditions where no messages are shown at all to the user, which may be undesirable. If you do use any of the printers by default, then you must ensure the correct level is enabled by default, for example if you use `warn, info, or okay` then you should make sure DEBUG_MODE is set to true (0) by default in your script. Similarly, `TRACE_MODE` must also be set for its higher level printers. Generally `DEV_MODE` should always be off by default. In case of non-optional printers, this means the user will not have to use a `-d` flag to enable them, but the environment can still override it by setting `DEBUG_MODE=1`, in this case it may be prudent to advise the user that stderr loggers are being surpressed by the environment and critical messages may not appear. By default all stderr, error and fatal messages cannot be surpressed. This system is in place due to the principle that stdout messages are reserved for automation and streaming.

-   **Silenceability (`QUIET(n)`):** All printer functions have a defined quietness level, controlled by flags (`opt_debug`, `opt_trace`) or modes (`QUIET_MODE`, `DEBUG_MODE`), ensuring predictable output behavior, these can be extended or hooked into as needed. 


## 4.5 Principle of Visual Friendliness


**Ceremony With Automation**

BashFX introduces the notion of ceremonies: clear visual demarkation of important state progression, critical warnings, and helpful visual patterns that walk a user through various path progressions. This typically includes things like ascii banners, structured data, boxes, clearly numbered and labeled steps, visual summaries, colors, glyphs and even occasional emojis. To this end BashFX provides a rich stderr.sh and escape.sh libraries that provide some curated color palettes and glyphs used over the years as part of BashFX's visual identity. Where these libraries are not immediately accessible, or perhaps even overkill for small scripts, the FX architecture requires developers to provide a minimal implemenation of tried and true patterns, and be proactive about communicating state (start, prev, curr, next, end).

Depending on the complexity or criticality of a state, certain ceromnies can be skipped via standard automation-enabling/disabling flags:  `opt_yes`, `opt_auto`,  `opt_force`, `opt_safe (an elevated no)`, `opt_danger (an elevated yes)` depending on the use case. Dangerous actions should generally not be permitted without additional overrides or explicit user consent. Inteligent use of standard modes like `DEV_MODE`, `SAFE_MODE` or `DANGER_MODE` can guide safe progression or open up more features to power-users.

**Testing Suites**

Using the stderr patterns in the Testing Suites, is critical for maintaining visual parity. Additionally testing suites should by default provide ceremony for each progressive step in the suite, clearly denoting the test number, a easy to read label indicating the tests or actions being performed, and ending the ceremony with a STATUS message like STUB (blue), PASS, FAIL, INVALID (purple). Stub means a test that should be completed but only has a reminder for the moment. Invalid means the test cannot be perfomred because dependent conditions are not met (usually enviroment related). Use of standard glyphs like checks, boxes, Xs, delta (for warning), etc are highly encouraged.

Each ceremony should be seperated with enough whitespace for visual parsing, and the entire suite should end with a summary ceremony indicating the metrics of the test, which tests failed, how long they took to run, and noting any abnormalities in the environment (invalids), since each test should be independent, an invalid state in one test should not invalidate another. 

**Other ceremony examples TBD, but general rules apply:**

- **Status and State Progression**
- **Critical Message Prompts**
- **Important Notices**

<br>


