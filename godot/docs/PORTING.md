# Porting conventions (C/C++ match engine -> GDScript)

The goal is a **line-by-line port** of the original Actua Soccer / Euro 96 match engine
(`SOURCE/*.CPP`) to GDScript 4.3. Do not redesign, simplify, "fix" or emulate: translate.
Every function, branch, magic number and comment of the original must have a counterpart.

## Class layout

```
CBase (scripts/core/cbase.gd)        C runtime helpers: u8/s8/s16/iabs/c_rand/bi ...
  └ GlobConsts (scripts/core/consts.gd)   every #define constant (generated)
      └ Glob (scripts/core/glob.gd)       every global variable + struct classes (generated)
          └ Maths, Ball, BallInt, Actions, Intell, Rules, User, Football, Upd3D, NetInput ...
```

* One script per original source file in `scripts/game/`:
  `maths.gd`(MATHS.CPP) `ball.gd`(BALL.CPP) `ballint.gd`(BALLINT.CPP) `actions.gd`(ACTIONS.CPP)
  `intell.gd`(INTELL.CPP) `rules.gd`(RULES.CPP) `user.gd`(USER.CPP) `football.gd`(FOOTBALL.CPP)
  `upd3d.gd`(3D_UPD2.CPP) `netinput.gd` class NetInput (the local-input parts of NETWORK.C) `audio.gd`(MY_AUDIO/AUDIO stubs).
* Header of each: `class_name <Module> extends Glob`. **All functions are `static func`.**
* Keep the original function names, parameter names, local variable names, order of
  functions, and comments (`//` -> `#`). Put the original C signature in a comment above
  each function: `# void init_run_act(match_player *player,float tx,float ty,char s)`.
* Calls to functions of the same file: unqualified. Calls to another file: `Module.func(...)`
  — see `docs/FUNCTION_INDEX.md` for which module owns which function.
* Globals (glob.gd) and constants (consts.gd) are used **unqualified**, exactly like C.
  Never redeclare them. If the C file has file-scope variables or function-local `static`
  variables that are not in glob.gd, declare them at the top of your module as
  `static var <name>` (prefix with the function name if a local static: `static var fn__name`).
* Constants: use the original macro names. Values come from `consts.gd` (being recovered
  from the original object code). If a macro is a parameterised/expression macro defined
  inside the .CPP (e.g. `#define DIVE_FEET_DIST (prat*4)` – depends on a variable), turn it into
  a `static func DIVE_FEET_DIST() -> float:` in your module (or inline it with a comment).
* `#ifdef X` / `#ifndef X` / `#else`: keep **both** branches as `if X:` / `if not X:` /
  `else:` using the boolean flag constants in consts.gd (EURO96, SUPPORT_LP, FRONT_END,
  STOP_TIME_WASTING, FORCE_SELECT, NET_GAME, ECTS ...). If the conditional wraps declarations
  so that it can't be an `if`, pick the branch matching the flag's value and comment the other.
  `#if 0`/commented-out code: keep as comments.

## Types and arithmetic (fidelity matters!)

* Declare every local with its C type mapped: `int/short/char/long` -> `int`,
  `float/double` -> `float`, pointers to structs -> the struct class (`match_player`),
  arrays -> `Array`. e.g. `var d: float`, `var p: int`.
* **Integer division**: in C `int/int` truncates toward zero; GDScript does the same for
  `int/int`, so keep operands' types identical to C. If C mixes an int with a float
  literal (`x/2.`), use a float literal in GDScript (`x/2.0`). Watch for `(float)` casts:
  `(float)a/b` -> `float(a)/b`.
* Assigning a float expression to an int variable/field: wrap in `int(...)` (C truncates).
* **`char` is UNSIGNED (Watcom default)**; `signed char` is signed. Struct fields' C types
  are in the comments of glob.gd. When a value that could be negative or >255 is stored
  into a `char` (or an `unsigned char`) variable/field, wrap it: `u8(v)`. `short`: `s16(v)` only
  where overflow is plausible. Comparisons of an unsigned char with negative numbers must
  keep C semantics (e.g. `c==-1` is always false for a `char`).
* `abs(x)` in C is the **integer** abs: with a float argument it truncates first (verified in
  the object code). Port `abs(...)` as `iabs(...)`; `fabs(...)` as `absf(...)`.
* `sqrt, sin, cos, tan, atan, atan2, asin, acos, floor, ceil, pow, fmod` -> GDScript
  equivalents (`sqrt`, `sin`, ... `fmod`). `modf(v,&n)` -> `c_modf(v)`.
* `rand()` -> `c_rand()`, `srand(s)` -> `c_srand(s)`. Never use Godot's RNG in game logic.
* C truthiness: `if (x)` -> `if x:` works for ints and floats. But a boolean expression
  used **as a number** (`a=(b>c);`, `x+=(y&&z);`, returning `a==b` from an int function,
  storing `!x` in an int) must become an int: `bi(b>c)`. `!x` in a condition -> `not x`.
* `TRUE`/`FALSE` are the ints 1/0 (CBase). Functions declared `char`/`int` return ints.
* Bitwise ops `& | ^ ~ << >>` are the same. `x++`/`++x`/`x--` inside expressions: expand
  into separate statements preserving the evaluation order.
* Ternary `a ? b : c` -> `(b if a else c)`.

## Pointers, structs, arrays

* `match_player *p` -> `p: match_player`; `&teams[i]` -> `teams[i]`; `p->x` -> `p.x`.
  `player-teams` (pointer arithmetic to get an index) -> `player.tm_player-1`.
  A null pointer is `null`.
* Global struct instances (e.g. `refs[3]`, `strike[11]`, `wguys[5]`) are pre-allocated in
  glob.gd; never replace them with new objects unless the C code copies a struct
  (`a=b` struct assignment / memcpy) — then copy field by field (write a small helper).
* Arrays are nested GDScript `Array`s in C index order: `match_tactics1[z][i][0]`.
  `memset(arr,0,...)` -> fill loops. `sizeof` -> literal sizes.
* **Reference parameters** (`float &x`): GDScript cannot pass scalars by reference. Such a
  function returns an `Array` with the final values of the reference params in parameter
  order, preceded by the C return value if the function is non-void:
  ```
  # void get_face_xy(int d,float &x,float &y)
  static func get_face_xy(d: int, x: float, y: float) -> Array:   # returns [x, y]
  # call site:
  var r := Intell.get_face_xy(d, x, y); x = r[0]; y = r[1]
  # int pass_ahead(int ps,float &x,float &y,float &pass_speed,float &end_speed,char cross)
  #   -> returns [ret, x, y, pass_speed, end_speed]
  ```
  (Array parameters such as `int tac[70][10][2]` are already references; pass them as is.)
  Functions with reference params: random_vector, rotate_offs, get_closest_pred, close_angle,
  centre_pos, gkick_pos, corner_pos, throw_in_pos, dfkick_pos, fkick_pos, penalty_pos,
  tunnel_pos, get_target, forward_joystick, get_face_xy, pass_ahead, choose_pass, dribble_dir,
  aim_shot_at_goal (check each signature in the source; there may be more).
* Default arguments (`char ride=FALSE`) -> GDScript default arguments.
* Function pointers / qsort: write a comparator `static func` and use `Array.sort_custom`
  (`Callable(<Module>, "name")`); note that qsort is not stable — keep the same comparator.

## Control flow

* `switch`: use `match` only when every `case` ends with `break`/`return` and labels are
  constants (`CONST_A, CONST_B:` for stacked labels). **Never put `break` inside a GDScript
  `match` branch to end a case — in GDScript it breaks the enclosing loop.** For fall-through
  or complex switches use an `if/elif` chain.
* `for(i=a;i<b;i++)` -> `for i in range(a,b):` only when the body doesn't modify `i` and `i`
  isn't used after the loop; otherwise a `while` loop with explicit increment (remember
  `continue` must still increment!).
* `goto` -> restructure minimally, comment it.
* Keep early `return`s.

## Things that are not ported

* Networking (NETNOW, modem, packets, state save/restore/checksums for net sync) – omit
  but keep the call sites as comments (`# NETWORK: ...`). `network_on` is always 0.
* Direct hardware/video code (VGA/VESA, palette writes, 2D editor/debug displays,
  `printf`) – omit or `print()` behind a debug flag.
* 3DENG.C functions called by the logic (`do_*_menu`, `do_*_anim`, `stadlist`, `sub_pending`, `setscreen`, `end3d`): call them via `Eng3D.` (scripts/game/eng3d.gd) — do NOT comment them out. 3DENG `get_dir(int user_no)` is `Eng3D.get_dir`.
* Audio calls (`play_fx`, commentary, crowd functions): call the stubs in `Audio`
  (`Audio.play_fx(fx, x, y)` etc.) with the same arguments so a sound layer can be plugged in.
* Rendering: `3DENG.C` is replaced by the Godot renderer (`scripts/render/`). The ported
  `3D_UPD2.CPP` (`upd3d.gd`) still computes camera position/target and the per-player
  `plyrdat` records exactly as before; the renderer consumes them.

## Style

* Tabs for indentation (Godot default). Static typing where obvious.
* Add `@warning_ignore("integer_division")` at the top of the file
  (`@warning_ignore_start` is not available in 4.3; instead set it per function or accept the warnings).
* Each file must parse: `godot --headless --path godot --check-only --script res://scripts/game/<file>.gd`
  is not reliable for class_name scripts; use the project test runner `tools/check.sh`.

## Macros that depend on variables (recovered)

* `MAX_TURN`  = `((14+(float)player->tm_rate/8)*PI/180)` – uses the local `player`; inline it as
  `((14.0+float(player.tm_rate)/8.0)*PI/180.0)`.
* `MAX_TURN2` = `((14+(float)teams[p_num-1].tm_rate/8)*PI/180)` – inline likewise.
* `D2RAD` is the unparenthesised `PI/180`: `x*D2RAD` means `x*PI/180`.
* `AFEQS(a,b)`, `LIMIT(v,lo,hi)` and `ABS(a)` (the type-preserving macro, unlike C `abs()`) exist as helper functions in CBase.
* `prat`-scaled distances (STEP_RANGE, DANGER_AREA, ...) are already constants (prat never changes).
* The numeric ORDER of `match_mode` values and `*_ACT` values matters (range tests) – always use
  the names, never literals.
