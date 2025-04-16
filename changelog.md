# Changelog

## 0.1

- Initial release.

## 0.2

- Add note tag system.
    - use `tag <index> <tag>` to give the tag to a note at index.
    - use `sel <tag>` to list all tags with given tag.
- Open local `.nf` file if available. This allow to have per folder projects.
    - use `notes nl` to open the global Notes file.
- General improvements and fixes. Check `pr 0.2` for more info.


## 0.2.1

- Linux support
    - Fix wrong data path on linux. It requires the shell to have `$HOME` set.
- Bug: Fix crash when it didn't had contain a file in the data directory.
