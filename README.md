# Attimo

Attimo (working title) is a 3D third-person platformer, built as a university prototype (vertical slice). The player character caused the apocalypse by accident and wants to get back to the lab, crossing a ruined, overgrown world with a steampunk prosthetic hand as the central tool. The Godot project lives in `attimo/`.

## Engine pin

- Godot **4.7.2-stable**, standard build (not .NET).
- The exact `--version` string is `4.7.2.stable.official.ed1daf0bf`. Every machine must report exactly this.
- macOS universal zip `Godot_v4.7.2-stable_macos.universal.zip`, SHA-512:

  ```
  38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca
  ```

  Official checksums: https://github.com/godotengine/godot/releases/download/4.7.2-stable/SHA512-SUMS.txt
  Verify before extracting: `shasum -a 512 Godot_v4.7.2-stable_macos.universal.zip`.
- Install path (macOS): `$HOME/Applications/Godot_4.7.2/Godot.app`
  (`ditto -x -k Godot_v4.7.2-stable_macos.universal.zip "$HOME/Applications/Godot_4.7.2/"`).
  The binary is then `$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot`.
- The `GODOT` environment variable overrides the path to the binary. The test script uses it, and it is how you point any machine at the pinned engine:

  ```
  export GODOT="$HOME/Applications/Godot_4.7.2/Godot.app/Contents/MacOS/Godot"
  "$GODOT" --version   # must print 4.7.2.stable.official.ed1daf0bf
  ```
- Windows: use the standard win64 zip of the same release, verified against the same SUMS file. Set `GODOT` to the exe and run the tests from Git Bash. The project already selects D3D12.
- **Never open `attimo/` with any other Godot version.** Older editors (4.6.3 and Godot 3 exist on the dev Mac) rewrite `project.godot` and the `.import` files.

## Run and test

```
bash attimo/tests/run.sh                      # import + all smoke tests
bash attimo/tests/run.sh test_jump_fact       # comma-separated substring filter
bash attimo/tests/run.sh --tool res://tools/<script>.gd   # run an editor-time tool headless
```

`run.sh` refuses (exit 3) any binary whose `--version` is not the pinned string, imports the project, runs the smoke tests and fails on `SCRIPT ERROR`, `Parse Error`, `Failed to load` or `Failed loading resource` in the logs. The last line is `RUN.SH: PASSED` or `RUN.SH: FAILED (<reason>)`.

Open the editor with `"$GODOT" --path attimo -e`, and press F5 to run the project.

## Repository layout

- `KayKit/` is the tracked shared reference library of raw asset packs. It lies outside the Godot project, so Godot never imports it (D-02).
- Used files are **copied**, never moved, into `attimo/assets/` (D-04).
- No Git LFS (D-03).
- `docs/` holds documentation, `.planning/` holds the planning artifacts.
- `attimo/` is the Godot project root (D-01) with the folders:
  - `scenes/`, `scripts/`, `assets/`, `autoload/` (D-05)
  - `tests/` (headless harness and smoke tests) and `tools/` (editor-time scripts)
  - naming: files `snake_case`, nodes and classes `PascalCase`
  - details: `docs/CONVENTIONS.md` (collision layers, groups, naming, Input Map actions)

## Branching

Phase work happens on the `dev` branch. Merge into `main` only after the phase has been verified.

## Credits

Character, animation and prototype geometry packs by Kay Lousberg (KayKit, www.kaylousberg.com), licensed CC0 (Creative Commons Zero). The licence files are inside each pack under `KayKit/`. Crediting is not mandatory but appreciated.
