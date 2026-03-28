# Part I: The Guiding Philosophy


## The "Herding Cats Architecture" for "Junkyard Engineering"

### 1.0 The Naming Ethos

The **FX** moniker stems from a deep fascination with functions (`f(x)`), set notation, logic, and discrete mathematics. Whenever these monikers are used in BashFX, it's an expression of joy and wonder at elegant systems. Similarly, other monikers in this realm exist: **GX** for generator (`g(x)`), **IX** for instruction (`i(x)`), among others. These are used consistently across various software solutions.

This preference for variables that resemble quasi-math notation aligns squarely with Unix's penchant for abbreviated namespacing. This desire is baked into BashFX, leading to a strong preference for terse variable and function names that are more emblematic of mathematical expressions, while allowing for deviation as necessary for clarity. BashFX will prefer, for example, iterators like `i, j, k`; spatial markers like `x, y, z`; set or comparison markers like `a, b, c`; and grammar or logic markers like `p, q, r`.

### 1.1 The Principles

These are the established conventions. They are not divine law, but ignoring them has a tendency to lead to long, unpleasant nights of debugging.

| Principle       | Description                                                                                                                                              |
| :-------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Self-Contained**  | All installation artifacts (libraries, configurations, binaries) must reside within a single, predictable root directory (e.g., `~/.local`). Don't make a mess in my home. |
| **Invisible**       | Don't throw your junk everywhere. No new dotfiles in `$HOME`. A good tool is heard from when called upon, and silent otherwise.                           |
| **Rewindable**      | Do no harm. Every action must have a clear and effective undo. An install without an uninstall is just graffiti.                                       |
| **Confidable**      | Don't phone home. Don't leak secrets. Trust is a non-renewable resource.                                                                                 |
| **Friendly**        | Follow the rules of engagement. Be proactive in communicating your state and use tasteful visual cues (color, symbols) for those of us who think with our eyes. |
| **Self-Reliance**   | A BashFX tool should not require a trip to the package manager for its core function. We build with what's already on the floor: `bash`, `sed`, `awk`, `grep`. |
| **Transparency**    | The system should be inspectable. A clever one-liner is admirable, but a black box is a liability. Favor clear, explicit actions over solutions that hide their intent. |

- **Guest Oath**. Any app, script, tool, library, etc. that intends/pretends to be a useful guest on a host system must:
    - Respect its non-permanent place in the universe (deletable).
    - Must not leak secrets about me without my consent (confiable).
    - Must undo any changes it attempts to make (rewindable).
    - Must not throw its junk everywhere with disregard (invisible)
    - Must not make a mess in my home (self contained) and 
    - Must follow customary rules of engagement. (friendly)
    - Failing any of these rules causes HARM to my system and is thus an open act of hostility.


