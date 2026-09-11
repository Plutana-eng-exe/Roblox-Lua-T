# AirHub — Development Workflow

## Repository
`https://github.com/Plutana-eng-exe/Roblox-Lua-T`  
Working directory: `AirHub/`

---

## One-time setup

1. **Install Git** — https://git-scm.com/download/win  
2. Open PowerShell in the `AirHub/` folder and run:

```powershell
# Allow the helper script to run (only needed once per machine)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

---

## Making changes and pushing

Edit any file in `AirHub/`, then run the commit helper:

```powershell
.\commit.ps1 -Version "v1.1.0" -Message "describe what you changed"
```

This will:
1. **Snapshot** the current `main.lua`, `UI Library.lua`, and `Depo/` into `versions/v1.1.0/`
2. **Commit** everything to git
3. **Push** to `main` on GitHub

---

## Version folder layout

```
AirHub/
  versions/
    v1.0.0/          ← initial release snapshot
      main.lua
      UI Library.lua
      Depo/
        Aimbot.lua
        ESP.lua
        Library.lua
    v1.1.0/          ← created by commit.ps1
      ...
```

Old versions are **never deleted** — each folder is a permanent snapshot.

---

## URL reference

The custom Drawing Library is now loaded from the repo itself:

```
https://raw.githubusercontent.com/Plutana-eng-exe/Roblox-Lua-T/refs/heads/main/AirHub/Depo/Pizza/Pastbin.lua
```

To update it, edit `AirHub/Depo/Pizza/Pastbin.lua` and run `commit.ps1`.
