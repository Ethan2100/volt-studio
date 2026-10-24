# Making a new release

GitHub builds the installer for you. You never need to download or upload the big Setup file.

1. **Upload your code changes** to the repo (Add file → Upload files → Commit changes).
2. Open the **Actions** tab at the top of the repo.
3. Click **Build and release** on the left.
4. Click **Run workflow** (on the right). Fill in:
   - **New version number:** one higher than the last, like `1.4.1`
     - small fix → change the last number (1.4.0 → 1.4.1)
     - new feature → change the middle number (1.4.1 → 1.5.0)
   - **What's new:** one line, for example `Adds stepper speed ramping`
5. Click the green **Run workflow** button.

After about 10 minutes the run shows a green tick, and the new release appears under **Releases** with the installer attached. It becomes the "latest" one, so the share link always gives people the newest version:

`https://github.com/Ethan2100/volt-studio/releases/latest`

**If it goes red:** click the failed run to see which step broke. The most common one is "Check the version number", which means the version was typed wrong or was already used.
