# Part II: System Structure & XDG Compliance

This part defines BashFX's hierarchical approach to system structure and its adherence to the XDG Base Directory Specification.

### 2.0 Layered Standards: XDG(0), XDG(1), XDG(2)

This architecture employs a layered approach to system standards.

- The first layer comprises standards aligned with widely adopted Linux/Unix conventions, collectively referred to as **XDG (standards)** or `XDG(0)`. This represents the upstream XDG Base Directory Specification.
- The second layer defines **Super Standards**, referred to as XDG+ or `XDG(1)`, which supersede, override, replace, or add preferred conventions for BashFX. This means XDG+ includes XDG(0), except where explicitly or implicitly overridden. XDG(1) is the default standard for BashFX compliance.
- Furthermore, XDG+ provides for additional layering: optional, extended, or use-case specific standards are referred to as **Extended Standards or `XDG(2)`.

When "XDG" is used as a flag, variable, prefix, or other code asset in any context within this architecture, it generally refers to XDG+ overall, without distinguishing between XDG(0) and XDG(1). However, additional custom namespacing may be used for XDG(2). 

The "XDG" phrasing serves as a hat-tip to upstream Linux standards and carries special meaning in code. Typically, any setup, launch, or base configurations will use XDG prefixes and names to indicate an early-stage setup, distinct from a runtime (post-install) setup. Conceptually, however, XDG+ is interchangeable with mentions of "**FX**," which encapsulates the essence and spirit of the BashFX architecture.

### 2.1 XDG Standard - XDG(0)

The XDG Base Directory Specification (**XDG(0)**) defines the following environment variables and their default paths for user-specific data:

| Variable          | Default Path        | Description                                                       |
| :---------------- | :------------------ | :---------------------------------------------------------------- |
| `XDG_CONFIG_HOME` | `~/.config`         | User-specific configuration files.                                |
| `XDG_CACHE_HOME`  | `~/.cache`          | User-specific non-essential data files.                           |
| `XDG_DATA_HOME`   | `~/.local/share`    | User-specific data files.                                         |
| `XDG_RUNTIME_DIR` | `/run/user/<uid>`   | User-specific runtime files and other file objects.               |

BashFX maintains a minimum respect for these **XDG(0)** standards, ensuring it does not clobber other libraries that adhere to them.

### 2.2 XDG+ Standard - XDG(1)

BashFX's **XDG(1)** standard represents a pragmatic deviation from **XDG(0)** due to its principles of no-pollution, self-containment, and "Don't F**k With Home" (**DFWH**). While **XDG(0)** scatters configuration and cache directories directly into `$HOME` and lumps everything else into `$HOME/share` without providing clean namespaces for common conventions like `etc`, `lib`, and `data`, BashFX streamlines this by primarily utilizing `$HOME/.local`.

**No Alteration of $HOME Policy.** Importantly, as part of the DFWH policy, we also do not attempt to *change* the users `$HOME` variable for any testing or virtualization since this could have dangerous side effects on legacy systems that depend on the exactness of this variable. Instead BashFX scripts rely on `XDG_HOME` variable usually provided by the environment as a mechanism for inheriting the users `HOME` value, but also providing a way to altering it safely for sandboxing and virtualization. This is part of the XDG+ Home Policy as futher extended upon below.


BashFX uses `$HOME/.local` (XDG_HOME) as its primary clean-up mechanism for the `$HOME` directory, defining its structure as follows:

| Variable    | Path                  | Description                                                                                                                                                                                                   |
| :---------- | :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `XDG_LIB_HOME`   | `$HOME/.local/lib`    | Script and library packages installed by BashFX are copied here.                                                                                                                                              |
| `XDG_ETC_HOME`   | `$HOME/.local/etc`    | Configuration files go here ceremoniously. BashFX strongly prefers this over `~/.config`.                                                                                                                      |
| `XDG_DATA_HOME`  | `$HOME/.local/data`   | Meant for data libraries like database files, dictionaries, and reference JSONs.                                                                                                                              |
| `XDG_BIN_HOME`   | `$HOME/.local/bin`    | A script is considered installed if it's symlinked here. Executables are typically symlinked directly into this path to maintain a flat, discoverable binary path.                                             |
| `XDG_TMP_HOME`   | `$HOME/.cache/tmp`    | The designated local temporary folder to use instead of `/tmp`.                                                                                                                                               |
| `XDG_HOME`  | `$HOME/.local`        | Generally considered the base for BashFX's local resolution of `XDG+` paths.                                                                                                                                  |


**XDG+ Home Policy** 
BashFX is strongly against adding *any* file directly to the user's root `$HOME` directory. Temporary development files may be permitted to spill over when `XDG` pathing is unavailable for specific setups, but such files must be manually cleaned up or subject to automated cleanup routines. Scripts created by other people will presumably have their own organization space, or alternatively a `my` space.

Important Update: Note that all XDG+ variable paths end in _HOME and not _DIR as  the standard XDG pattern for installed applications and user data; Linux systems use a _DIR suffix to indicate folders like Desktop and Downloads that are only available on *Desktop* distros. 

**XDG+ Lib-to-Bin Installation Pattern** 
On that note, first-class fx scripts (scripts create by/for Bashfx) typically install into the `XDG_LIB_HOME\fx` directory in a folder under their explicit app name space. Example the padlock script  `XDG_LIB_HOME\fx\padlock\padlock.sh`. When scripts are linked to the fx bin path `XDG_BIN_HOME\fx` the links are all flattened into the fx namespace and do not use the .sh extension.

`XDG_LIB_HOME\fx\padlock\padlock.sh` -> installs via link to -> `XDG_BIN_HOME\fx\padlock` (no .sh)


**XDG+ TMP Policy**
BashFX scripts that require temporary directories and files should *not* use the standard `\tmp` directory, and should instead decide of a project local `./.tmp` folder or the XDG+ TMP directory `$XDG_TMP_HOME` should be used instead. Due to the number of permission issues that can occur with root path directories we generally try to avoid them including `/tmp`. However any such tmp artifacts should be deleted at the end of execution or otherwise scheduled for deletion as to not cause clutter. Any tmp folders or files used in a project must be added to the `.gitignore` facility file to properly prevent inclusion in commits.


### 2.3 Directory Awareness

We leverage standard directory names to maintain consistency with ancient patterns that remain relevant. This principle extends to other well-established folder naming conventions not explicitly listed here. When files are added to system-level paths, this standard requires proper use of directories as implied by their name.

**Linux Standard Directories - DIR(0)**

This refers to the general use of standard names for derived pathing, often found in traditional Unix-like file systems.

| Name   | Purpose                                     |
| :----- | :------------------------------------------ |
| `etc`  | Configuration files                         |
| `data` | Variable data files                         |
| `lib`  | Essential shared libraries and modules      |
| `tmp`  | Temporary files                             |
| `var`  | Variable data, like logs and spools         |

*(Note: These conventions align with historical FHS - Filesystem Hierarchy Standard - principles for system-wide directories, adapted here for user-specific contexts.)*

**BashFX Standard Directories - DIR(1)**

These are additional standardized directory names integrated over the years, and are considered standard if their use case arises within BashFX.

| Name   | Purpose                                                                                                                                                                                                  |
| :----- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `www`  | Web root directories, typically used instead of `public`.                                                                                                                                                |
| `env`  | Environment variables, profile-scoped variables, and preferences.                                                                                                                                        |
| `cdn`  | Static assets like CSS, JavaScript, and images.                                                                                                                                                          |
| `repos`| A top-level directory for Git repositories, often namespaced.                                                                                                                                            |
| `my`   | User-specific customizations, personal dotfiles, or a custom user root.                                                                                                                                  |
| `dx`   | User-specific code and code configuration.                                                                                                                                                               |
| `zero` | Housing new/fresh user-preferred system configurations for migrations.                                                                                                                                   |
| `x` or `root` | A pseudo top-level "mount point" in `$HOME` for all user-specific data, allowing for clean removal, syncing, or backup. Items from this directory are typically symlinked into `$HOME` if needed. |




