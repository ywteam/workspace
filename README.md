# 🩳 Yellow Team Workspace

## Workspace CLI

### Screenshots

<!-- ![image](https://github.com/ywteam/workspace/assets/483708/fcfc3fa8-da59-475e-a320-902c66377ac5) -->

### Usage

```shell
Usage: workspace [options] [command]
```

### Options

| Option | Description |
| --- | --- |
| `-V, --version` | output the version number |
| `-h, --help` | display help for command |

### Commands

| Command | Description |
| --- | --- |
| `compose` | Handle compose commands with all compose files available |
| `dotenv` | Handle dotenv commands with all dotenv files available |
| `help` | Display help for command |

#### Compose

| Command | Description |
| --- | --- |
| `up` | Create and start containers |
| `down` | Stop and remove containers, networks, images, and volumes |
| `start` | Start services |
| `stop` | Stop services |
| `restart` | Restart services |
| `logs` | View output from services |
| `ps` | List services |
| `exec` | Execute a command in a running container |
| `build` | Build or rebuild services |
| `pull` | Pull service images |
| `push` | Push service images |
| `config` | Validate and view the compose file |
| `create` | Create services |
| `rm` | Remove stopped containers |
| `run` | Run a one-off command |

#### Dotenv

| Command | Args | Description |
| --- | --- | --- |
| `files` | | List dotenv files |
| `load` | ...files | Load dotenv files |

```shell
    compose     [docker compose command]    Handle compose commands with all compose files available
    dotenv      [dotenv command]            Handle dotenv commands with all dotenv files available
    help        [command]                   Display help for command
```



## Semantic Commit Messages

See how a minor change to your commit message style can make you a better programmer.

Format: `<type>(<scope>): <subject>`

`<scope>` is optional

## Example

```
feat: add hat wobble
^--^  ^------------^
|     |
|     +-> Summary in present tense.
|
+-------> Type: chore, docs, feat, fix, refactor, style, or test.
```

More Examples:

- `feat`: (new feature for the user, not a new feature for build script)
- `fix`: (bug fix for the user, not a fix to a build script)
- `docs`: (changes to the documentation)
- `style`: (formatting, missing semi colons, etc; no production code change)
- `refactor`: (refactoring production code, eg. renaming a variable)
- `test`: (adding missing tests, refactoring tests; no production code change)
- `chore`: (updating grunt tasks etc; no production code change)
- `lint`: (fixing linting errors)
- `ci`: (changes to CI configuration files and scripts)
- `build`: (changes that affect the build system or external dependencies)
- `perf`: (a code change that improves performance)
- `revert`: (reverts a previous commit)
- `merge`: (merge branch)
- `release`: (release version)
- `security`: (security fix)
- `breaking`: (breaking changes)
- `config`: (changes to configuration files)
- `deploy`: (deploying code)
- `infra`: (changes to infrastructure)
- `data`: (changes to data)

References:

- https://www.conventionalcommits.org/
- https://seesparkbox.com/foundry/semantic_commit_messages
- http://karma-runner.github.io/1.0/dev/git-commit-msg.html

## Submodules

### Adding a submodule
```shell
git submodule add <repository_url> <folder_path>
```
### Removing a submodule

- Delete the relevant section from the .gitmodules file.
- Stage the .gitmodules changes via git add .gitmodules.
- Delete the relevant section from .git/config.
- Run git rm --cached path_to_submodule (no trailing slash).
- Run rm -rf .git/modules/path_to_submodule.
- Commit the changes.
- Delete the now untracked submodule files rm -rf path_to_submodule.

```shell
git submodule deinit <folder_path>
git rm --cached <folder_path>
git commit -m "Removed submodule"
rm -rf .git/modules/<folder_path>
```