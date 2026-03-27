**Dev Workflow**
1. Copy/paste your Terraform source into this repo (primarily under `modules/`).
2. Run the flatten + static-analysis pipeline:
```powershell
python .\tools\brainboard_flatten.py
```
3. Review pipeline logs in hidden `build-logs` (`PASS`/`FAIL` is printed per step).
4. Import into Brainboard from Git:
- Select the **subfolder** `brainboard-import` (do not select a single file).
- Brainboard will read `brainboard-import/*.tf` automatically.
- If Brainboard says no Terraform files are found, ensure `brainboard-import/brainboard.tf` is committed and pushed to the selected branch.
- Fallback: copy `brainboard-import/brainboard.tf` to `brainboard-import/main.tf`, commit, push, and retry import.

**Important Paths**
- `brainboard-import/`: Generated Terraform for Brainboard import.
- `tools/`: Utility scripts (`brainboard_flatten.py`, `prune_repo.py`).
- `build-logs/`: Hidden run logs; script keeps the latest 3 logs only.
- `.vscode/settings.json`: Workspace editor settings for generated Brainboard Terraform.

**Brainboard vs Terraform AWS Provider (DynamoDB GSI)**
- Brainboard preflight currently expects legacy `global_secondary_index.hash_key` / `range_key`.
- Newer AWS provider schemas prefer `key_schema` blocks and may mark legacy keys deprecated in Terraform-aware tooling.
- This repository intentionally keeps legacy GSI keys in `brainboard-import/brainboard.tf` so Brainboard imports succeed.
- `tools/brainboard_flatten.py` enforces this conversion during generation.
- VS Code warning suppression is handled via `.vscode/settings.json` by opening the generated file as `hcl`, so schema deprecation diagnostics do not distract from Brainboard import workflows.

**Useful Commands**
```powershell
# Full flatten pipeline
python .\tools\brainboard_flatten.py

# Skip Checkov stage
python .\tools\brainboard_flatten.py --skip-checkov

# Generate only (no static analysis)
python .\tools\brainboard_flatten.py --skip-static-analysis --skip-checkov

# Brainboard preflight (regen + init + validate in brainboard-import)
powershell -ExecutionPolicy Bypass -File .\tools\brainboard_preflight_validate.ps1

# Clear repo helper
python .\tools\prune_repo.py

# Copy platform/terraform from main repo into this repo (read-only source)
python .\tools\copy_main_repo_terraform.py

# Master refresh: prune -> copy -> flatten
python .\tools\refresh_from_main_repo.py
```
