# Making a new Volt Studio release

The installer and Volt language have independent version numbers.

For this release:
- **Volt Studio installer/application:** `1.9.4`
- **Volt language/compiler:** `3.4.0`

## Build and publish

1. Merge the prepared feature branch into `main` after reviewing the pull request and test results.
2. Open the repository's **Actions** tab.
3. Select **Build and release**, then **Run workflow**.
4. Set **installer_version** to `1.9.4`.
5. Set **volt_version** to `3.4.0`.
6. Add release notes and run the workflow.
7. Wait for the Windows build, tests, compiler version check and installer packaging to finish.
8. Confirm the release has the Setup EXE attached before sharing it.

The workflow runs `npm ci` and `npm test`, builds the Windows application, packages it with NSIS, and publishes the installer to GitHub Releases. The workflow is not complete until its run is green and the release asset is visible.

Latest release link: https://github.com/Ethan2100/volt-studio/releases/latest

## Important

The Windows installer is currently unsigned, so Windows SmartScreen may show a warning. Users should only run the installer downloaded from the official Volt Studio repository.
