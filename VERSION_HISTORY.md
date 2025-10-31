# Version History

Track all major versions of the Investment Research App.

## How to Use

When you want to save a version, just tell me:
> **"save version: [your description here]"**

I'll create a git commit, tag it with a version number, and push to GitHub.

---

## Versions

### v1.0.0 - Initial Working Version (2025-10-26)
**✅ Saved to GitHub**

First working version with **100% free SEC-only data**:

**Data Architecture:**
- ✅ All data from SEC EDGAR API (no API keys, $0/month cost)
- ✅ Cloudflare Worker backend deployed
- ✅ Revenue data (quarterly and TTM) from SEC filings
- ✅ Earnings data (quarterly and TTM) from SEC filings
- ✅ Company ticker autocomplete from SEC ticker list
- ✅ App Store compliant (no paid APIs, no terms violations)

**Chart Features:**
- ✅ Revenue charts (quarterly & TTM) with 40 quarters displayed
- ✅ Earnings charts (quarterly & TTM) with dynamic Y-axis
- ✅ YoY growth charts (revenue & earnings) with color coding (green/red)
- ✅ Negative value support for earnings charts
- ✅ All charts use consistent blue color scheme
- ✅ Dynamic bar widths (no horizontal scrolling)
- ✅ Data tables showing up to 10 years of history

**Technical Details:**
- ✅ Charts extracted to separate files for fast compilation
- ✅ ChartUtilities shared formatting functions
- ✅ Consistent chart styling across all views
- ✅ All build errors resolved

**GitHub:** [View on GitHub](https://github.com/rileypgibson21-gif/investment-research-app/releases/tag/v1.0.0)

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
