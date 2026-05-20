# Zshrc Workspace Shortcuts

This zshrc defines shortcuts for the local workspace layout under:

```text
~/workspace
```

The structure follows a simple rule: keep one clear root, group client work by
client name, keep secrets separate, and document the standard so it stays easy
to use later.

Reference used for the folder-structure check:
https://www.suitefiles.com/guide/the-guide-to-folder-structures-best-practices-for-professional-service-firms-and-more/

## Workspace Layout

```text
~/workspace/
  work/
    clients/
      Cellutions/
        ssh/
        projects/
      VNG/
        secrets/
          ssh/
          vpn/
          certs/
          tokens/
          env/
          misc/
  learn/
    courses/
    books/
    notes/
    projects/
    references/
    archive/
  lab/
  scratch/
  archive/
```

Use `learn/` for structured study material. Use `lab/` for hands-on testing,
experiments, and proof-of-concepts.

## Exported Paths

```sh
WORKSPACE="$HOME/workspace"
WORK_DIR="$WORKSPACE/work"
CLIENTS_DIR="$WORK_DIR/clients"
CELLUTIONS_DIR="$CLIENTS_DIR/Cellutions"
VNG_DIR="$CLIENTS_DIR/VNG"
CELLUTIONS_SSH_DIR="$CELLUTIONS_DIR/ssh"
VNG_SECRETS_DIR="$VNG_DIR/secrets"
VNG_SSH_DIR="$VNG_SECRETS_DIR/ssh"
```

## Navigation Aliases

```sh
ws          # cd ~/workspace
work        # cd ~/workspace/work
clients     # cd ~/workspace/work/clients
cellutions  # cd ~/workspace/work/clients/Cellutions
vng         # cd ~/workspace/work/clients/VNG
cellssh     # cd ~/workspace/work/clients/Cellutions/ssh
vngssh      # cd ~/workspace/work/clients/VNG/secrets/ssh
```

Reload after edits:

```sh
source ~/.zshrc
```
