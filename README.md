# termux-ubuntu-bootstrap

Bootstrap a minimal, reproducible Ubuntu PRoot environment from Termux, then
layer a maintained set of command-line and development utilities on top.

## Status

This repository is being built from three previously functional local scripts.
The initial commit establishes the public repository contract and branch model;
the scripts will be refactored in subsequent commits without publishing the
original local references.

## Planned architecture

| Layer | Responsibility | Safety contract |
| --- | --- | --- |
| `01-bootstrap-termux-ubuntu.sh` | Install `proot-distro` and provision Ubuntu | Never replaces an existing Ubuntu unless invoked with `--fresh`. |
| `02-setup-ubuntu-base.sh` | Reconcile a declared profile of base, development, and network utilities | Installs only missing packages and upgrades the declared profile. |
| `03-update-ubuntu-profile.sh` | Refresh the packages already managed by the profile | Does not reinstall Ubuntu or add unrelated runtimes. |

The package profile will be shared by layers 2 and 3 so that they cannot drift.
The updater will manage distribution packages only; deprecated AI CLI setup from
the legacy maintenance script is intentionally out of scope.

## Safety model

- Run the bootstrap script from Termux.
- Run the base setup and updater from the Ubuntu PRoot as root.
- `--fresh` is the only mode allowed to remove an existing Ubuntu rootfs.
- Network checks must use HTTPS and report a useful failure.
- Package upgrades must be explicit, non-interactive, and limited to the
  declared profile unless a future full-system mode is added.

## Branches

- `dev`: integration branch for the initial refactor.
- `main`: stable branch; initially mapped to the verified `dev` setup commit.

## Local references

The supplied functional scripts are retained locally under `docs/reference/`.
That directory is intentionally ignored and excluded from archives, so it is
not part of the public repository or its releases.

## License

No license has been selected yet. Choose one before inviting reuse or external
contributions.
