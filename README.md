**Dev Workflow:**
1. Copy-Paste Terraform directory (platform/terraform/ from crumbs-scroogebank-repo) into root of this repositroy
2. run the flatten command
3. fix issues (if it exists)

**Unique Directories:**
- brainboard-import/
- tools/

**Replaceable Directories:**
- literally every other directory

**brainboard-flatten command:**
```python
python .\tools\brainboard_flatten.py
```

**clear-repo command:**
```python
python .\tools\prune_repo.py
```