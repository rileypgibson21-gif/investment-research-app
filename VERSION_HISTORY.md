# Version History

Track all major versions of the Investment Research App.

## How to Use

When you want to save a version, just tell me:
> **"save version: [your description here]"**

I'll create a git commit, tag it with a version number, and push to GitHub.

---

## Versions

### v1.0.0 - Initial Setup (Coming soon)
First working version with:
- Revenue charts showing 40 quarters (no scrolling)
- TTM revenue charts showing 37 periods (no scrolling)
- Skinnier bars with tighter spacing
- Cloudflare Worker backend deployed
- Marketstack API integration
- SEC API for company financials
- All compiler errors fixed

---

## Version Format

- **Major.Minor.Patch** (e.g., 1.0.0)
- **Major**: Breaking changes or major features
- **Minor**: New features, non-breaking
- **Patch**: Bug fixes, small tweaks

## Git Tags

Each version is tagged in git:
- `git tag` - See all versions
- `git checkout v1.0.0` - Go back to a specific version
- `git log --oneline` - See commit history
