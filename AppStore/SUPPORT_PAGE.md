# Keptora Support

Publish this page at the final support URL after replacing placeholders.

## Contact

Email: `[SUPPORT EMAIL]`  
Typical support languages: English and Turkish  
Version/build: include the value shown in Keptora Settings.

## Before contacting support

1. Open **Diagnostics** in Keptora.
2. Keep **Redact paths and file names** enabled.
3. Export the JSON support snapshot.
4. Describe what you expected, what happened, and whether an external drive was connected.
5. Do not send personal photos unless support explicitly requests a minimal test file and you are comfortable sharing it.

## Frequently asked questions

### Does Keptora upload my photos?

No. The current version processes the selected archive on the Mac and contains no photo-upload or analytics service. This also applies when the selected folder is an iCloud Drive or other cloud-provider folder mounted in Finder.

### Can I use iCloud Drive or another cloud provider?

Yes. Sign in to the provider in its Mac app first, wait until its folder appears in Finder, then choose **Connect Cloud Folder…** in Keptora. Keptora uses the Finder/File Provider folder locally and read-only; it does not ask for provider credentials or add direct cloud sync.

### Does Keptora permanently delete files?

No permanent-delete command is included in the current app target. Approved exact copies move to a reversible quarantine. Use History to restore them.

### Why can’t similar photos enter a Safety Plan?

Visual similarity is probabilistic. Keptora keeps those groups advisory so the user can compare them without allowing the model to authorize cleanup.

### How does the free tier work?

Scanning is unlimited. The first 100 unique review decisions are free. Re-editing a previously counted asset does not consume another review. A lifetime purchase unlocks unlimited review and Safety Plans.

### How do I restore a purchase?

Open Settings or the Pro sheet and choose **Restore Purchase**. Use the same Apple Account that acquired the non-consumable product.

### How do I restore files?

Reconnect and select the original source volume, open History, select the cleanup plan, and choose Restore. Do not manually alter the quarantine directory or manifest before restoring.

### The original drive is missing

Reconnect the same physical/logical volume. Keptora records volume identity to reduce the risk of restoring into the wrong location.

### How do I revoke folder or Photos access?

Use macOS System Settings → Privacy & Security and review the relevant file/folder or Photos permission.

## Known release boundaries

The first App Store version does not include direct provider account integration, cloud sync, an account, collaboration, Windows support, permanent Apple Photos deletion, or automatic cleanup of visually similar images. Finder-mounted iCloud Drive and other File Provider folders can be selected for local, read-only scanning.
