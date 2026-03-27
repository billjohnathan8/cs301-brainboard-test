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

**Useful Commands**
```powershell
# Full flatten pipeline
python .\tools\brainboard_flatten.py

# Skip Checkov stage
python .\tools\brainboard_flatten.py --skip-checkov

# Generate only (no static analysis)
python .\tools\brainboard_flatten.py --skip-static-analysis --skip-checkov

# Clear repo helper
python .\tools\prune_repo.py
```
