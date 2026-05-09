# Release Checklist

Before publishing:

- Choose a repository name, for example `wot-cursor-freeze-fix`.
- Choose a license deliberately. I did not pick one automatically.
- Replace `<link here>` in `docs/reddit-post-draft.md` after the repository is public.
- Decide whether to publish the prebuilt `bin/WotCursorHideCallPatch.exe` or only source plus build script.
- If publishing the binary, keep `CHECKSUMS.sha256` in the release notes.
- Add the exact WoT client version/build to the GitHub release description if you can identify it.
- Make it clear that unsupported versions should produce `status=unknown` and must not be force-patched.
