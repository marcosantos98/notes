# ncli - Note taking in the terminal

Take quick notes from your terminal without needing external tools.

> [!WARNING]
> This is a work in progress project and only tested on windows.

## Usage:

Currently it contains an interactive mode and a cli mode. In interactive mode it works like a simple shell, in cli mode you can chain various commands to change the state.

```
notes add "this note is cool" p other_project ls
```

The above command performs an `add`, a `sw` and a `ls` operation in a single cli command. More info can be obtain with `notes help`.

## isn't finished and why?

- [x] Support for multiple projects;
    - [ ] tags;
- [x] Note taking:
    - [x] add;
    - [x] remove;
    - [ ] edit;
    - [ ] link;
    - [ ] copy;
    - [ ] move;
    - [ ] tags;
- [ ] Filters;
- [ ] GUI version;
- [ ] WEB version (WASM);

## Current operations:

| command | description | hidden behavior |
| ------- | ----------- | --------------- |
| np <name> | create new project | sets the current project to the newly created project |
| del <name> | delete project | clears the current project. use `sw` afterwards |
| ls | list notes | - |
| lsp | list projects | - |
| lsi | list notes with index | - |
| sw <name> | switch current project | - |
| addn \| an \| add <note> | add note to current project | - |
| rn \| rm <index> | remove the note at the given index | - |
| cp | print info about current project | - |
| exit | exits the cli | - |
| help \| h | display help | - |

## Building:

The "app" is written in Odin, so we use the Odin compiler. I know, smart.

```
> build.bat release
```

Additionally we can use `-define:NOTES_PATH=<path>` to specify where the "app" will save and load its state.

```
> odin build . -:ospeed -define:NOTES_PATH="./mypath/notes.mom"
```

## Where it saves the notes, How and Why:

- `Where`: Notes are currently saved in `%APPDATA%/notes-global/global.bin`.
- `How`: It uses a custom file layout that is encoded and decoded. The save and 
load functionality is available at `filedata.odin`.
- `Why`: Using any sort of sql or other type of databases requires the user to have it installed, having local files are easier to mantain and the migration is done when versions missmatch, at least, that is the plan.

### FileLayout:

The currently working layout is version 1.

```
NFILE {
    u8 version;

    u16 current_project_name_len;
    [current_project_name_len]u8 current_project_name;
    
    u16 num_of_projects;
    [num_of_projects]Project;
}

Project {
    u16 project_name_len;
    [project_name_len]u8 project_name;

    u16 number_of_notes;
    [number_of_notes]Note;
}

Note {
    u16 note_len;
    [note_len]u8 note;
}

```
