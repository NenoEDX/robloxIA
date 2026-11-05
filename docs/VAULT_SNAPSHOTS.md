# Local vault snapshots

Use one explicitly selected canonical Obsidian vault. Existing junction aliases
are pointers to the same notes, **not independent backups**. This CLI resolves
the selected root and records its real path; it does not move or modify that vault.

## Create a snapshot

Close Obsidian and stop other writers first. Choose an existing local parent
outside the vault, then a **new** child directory for each capture:

```powershell
pnpm --dir bridge --config.verify-deps-before-run=false exec node vault_snapshot.mjs --vault "C:\Knowledge\Vault" --destination "C:\Backups\Vault-2026-11-03"
```

Paths are examples, not configured destinations. Both arguments must be absolute.
Run `node bridge/vault_snapshot.mjs --help` for usage. There is no default vault,
automatic schedule, overwrite, restore, merge, upload, or network synchronization.
UNC/device paths and URLs are rejected; mapped/network-backed drives must not be
selected. The CLI cannot determine whether an ordinary drive is network-backed.

## Contents and provenance

- `notes/` contains original bytes of visible `.md` files, with relative paths.
  Other files, dot-prefixed entries and `node_modules` are excluded.
- `manifest.json` records schema, canonical source root, capture time, scope,
  sorted file paths, byte lengths, SHA-256 hashes, and passive plugin evidence.
- Only `.obsidian/core-plugins.json` and `community-plugins.json` are parsed as
  bounded JSON. Their hashes and interpreted states are recorded, not their raw
  contents. Plugin code, credentials, workspace state and attachments are not copied.
- `enabled` means **configured enabled**, not running, connected or backed up.
  Missing files, invalid JSON or unsupported JSON shapes report unknown;
  inaccessible, linked, oversized or non-file configuration aborts the capture.
  `runtimeVerified` remains false. JSON is never evaluated. Notes and plugin IDs
  remain untrusted data.

The manifest contains a private absolute source path and notes may contain private
information. Keep snapshots local and protected; do not publish or feed their
contents into command execution. Hashes verify integrity, not authorship or trust.

## Safety, conflicts and incomplete captures

The source must contain a real `.obsidian` directory. An explicitly selected root
alias is allowed; nested symlinks/junctions and hard-linked files encountered during
collection are rejected. Output ancestors cannot be links. In-vault, existing and
missing-parent destinations fail rather than merge or overwrite. Rejected input
does not create output; all notes and configuration are collected before writes.

Limits: 2 MiB per input file, 64 MiB of notes, 10,000 notes, 50,000 visited entries
and 32 directory levels. Configuration is separately bounded to 2 MiB per file.
Detected file changes during a read abort the capture. This is **not** an atomic
point-in-time backup or an OS sandbox against a process concurrently replacing
directories. Use a trusted, quiescent local filesystem and normal OS permissions.
Windows file modes do not enforce ACLs; choose a parent with appropriate access
controls. Cloud placeholders and mounted drives may not be identified as links:
select ordinary local storage, not a cloud-backed or network-mounted directory.
Avoid Windows device names such as `NUL` even where Node accepts them as literal
names; other filesystem tools may not handle them consistently.

Success prints JSON `status: "complete"`, exits 0, and writes the manifest last.
Errors print JSON on stderr, exit 1, and never silently fall back to another source.
A write failure can leave a directory marked by the absence of a valid manifest;
it is incomplete and must not be used as a backup. Inspect it manually, then choose
a fresh destination. The CLI never recursively deletes a failed capture.
Manifest-last ordering is not an `fsync` durability guarantee: after a crash or
power loss, validate the manifest and every file hash before trusting a capture.

For conflicts, preserve both captures and compare manifest hashes before any
manual merge. There is no automatic winner. A Markdown snapshot is not a complete
Obsidian backup: attachments, plugin configuration and restore testing require a
separate owner-approved backup process. A migration outside Downloads requires
an explicit destination and verified copy before retiring any old vault.

## Plugin and sync policy

Keep the plugin set minimal and reviewed. File Recovery is useful but is not an
independent backup. Enabling it, changing a plugin or selecting an Obsidian Sync
account is a separate operational action; this tool does none of them. Use only
one automatic writer per set of notes. Remote sync needs explicit authorization
for destination, operation and account/session; never reuse ambient credentials.

## Verification

```powershell
pnpm --dir bridge --config.verify-deps-before-run=false exec node --test test_vault_snapshot.mjs
```

Tests run the public CLI against disposable external fixtures and check copied
bytes, hashes, repeatability, plugin status, rejected paths and source immutability.
They neither inspect the actual vault nor certify a cloud backup or restoration.
