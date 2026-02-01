# Changelog

## 0.1

- Initial release.

## 0.2

- Add note tag system.
    - Use `tag <index> <tag>` to give the tag to a note at index.
    - Use `sel <tag>` to list all tags with given tag.
- Open local `.nf` file if available. This allows per-folder projects.
    - Use `notes nl` to open the global Notes file.
- General improvements and fixes. Check `pr 0.2` for more info.


## 0.2.1

- Linux support
    - Fix wrong data path on Linux. It requires the shell to have `$HOME` set.
- Bug: Fix crash when it didn't contain a file in the data directory.

## 0.2.2
- Fix spelling and grammar in user-facing messages and docs.
