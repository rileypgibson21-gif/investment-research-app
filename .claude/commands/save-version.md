---
description: Save current project state as a version with description
---

You are saving a version of the project. Follow these steps:

1. Ask the user for a version description (what this version contains/does)
2. Create a timestamp in format: YYYYMMDD-HHMM
3. Create version directory: `versions/v{timestamp}/`
4. Copy important project files to the version directory:
   - All Swift files from `ios/Test App/`
   - `backend/src/index.js`
   - `backend/wrangler.toml`
   - `backend/package.json`
5. Create a VERSION_INFO.md in the version directory with:
   - Timestamp
   - Description provided by user
   - List of files included
6. Append entry to `versions/VERSION_LOG.md` with timestamp and description
7. Confirm to user that version was saved

Example structure:
```
versions/
├── VERSION_LOG.md
├── v20251026-2215/
│   ├── VERSION_INFO.md
│   ├── ios/
│   │   └── *.swift files
│   └── backend/
│       └── relevant files
```
