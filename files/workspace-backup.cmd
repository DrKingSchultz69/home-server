@echo off
rem One-way backup of the laptop Workspace to the server, run hourly by the
rem "Homeserver Workspace backup" scheduled task. Mirrors C:\Workspace to
rem \\homeserver\Backups\laptop-workspace (deleted files are removed there too).
rem Skips folders that can be rebuilt (dependencies and caches).
rem Exit codes 0-7 mean success; 8+ means some files failed.

robocopy "C:\Workspace" "\\homeserver\Backups\laptop-workspace" /MIR ^
  /XD node_modules .venv venv .next __pycache__ .cache .turbo ^
  /R:1 /W:5 /MT:4 /NP /NFL /NDL ^
  /LOG:"%LOCALAPPDATA%\homeserver-workspace-backup.log"
