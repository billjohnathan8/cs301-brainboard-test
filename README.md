# Brainboard Terraform Import Helper

## Prerequisites
- This workflow requires a **public GitHub repository**.
- Enable Brainboard GitHub integration in [Brainboard settings](https://docs.brainboard.co/settings/integrations/git-configuration/github).

## How to Run
```powershell
# Master refresh: prune -> copy -> flatten
python .\tools\refresh_from_main_repo.py
```

## Main Workflow
1. Add or sync Terraform source (mainly under `modules/`).
2. Generate flattened Terraform:
```powershell
python .\tools\brainboard_flatten.py
```
3. Check run results in `build-logs/` (`PASS`/`FAIL` per step).
4. In Brainboard Git import, select the `brainboard-import` **subfolder**.
5. If Brainboard cannot find files, ensure `brainboard-import/brainboard.tf` is committed and pushed. If needed, copy it to `brainboard-import/main.tf` and retry.

## Optional: Architecture View
```powershell
# Writes to brainboard-architecture-import/ (single subfolder for Brainboard import)
# Default mode is flow (keeps key traffic + security relationships)
python .\tools\brainboard_architecture_view.py
```

## Useful Commands
```powershell
# Full flatten pipeline
python .\tools\brainboard_flatten.py

# Skip Checkov
python .\tools\brainboard_flatten.py --skip-checkov

# Generate only (no static analysis)
python .\tools\brainboard_flatten.py --skip-static-analysis --skip-checkov

# Brainboard preflight (regen + init + validate in brainboard-import)
powershell -ExecutionPolicy Bypass -File .\tools\brainboard_preflight_validate.ps1

# Architecture view modes
python .\tools\brainboard_architecture_view.py --mode flow --clean
python .\tools\brainboard_architecture_view.py --mode compatible --clean
python .\tools\brainboard_architecture_view.py --mode core --clean
python .\tools\brainboard_architecture_view.py --mode core --allow-unresolved --clean

# Helpers
python .\tools\prune_repo.py
python .\tools\copy_main_repo_terraform.py
python .\tools\refresh_from_main_repo.py
```

## Important Paths
- `brainboard-import/`: Generated Terraform used for Brainboard import.
- `brainboard-architecture-import/`: Generated architecture-view Terraform used for Brainboard import.
- `tools/`: Utility scripts.
- `build-logs/`: Hidden logs (latest 3 kept).
- `.vscode/settings.json`: VS Code handling for generated Terraform files.

## Compatibility Note (DynamoDB GSI)
- Brainboard preflight expects legacy `global_secondary_index.hash_key` / `range_key`.
- This repo preserves that format in generated output for import compatibility.
- `tools/brainboard_flatten.py` enforces conversion and pins AWS provider `~> 5.0`.
