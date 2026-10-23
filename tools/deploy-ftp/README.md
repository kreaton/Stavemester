# deploy-ftp

A small command-line tool that uploads the contents of a local folder to an FTP server.
It can optionally run `dotnet publish` into that folder first, which makes it a stand-in for
Visual Studio's FTP publish profiles (those only work inside Visual Studio).

Nothing in it is specific to Stavemester: any folder can be uploaded to any FTP server.

## Build

Needs [Rust](https://rustup.rs).

```powershell
cargo build --release
```

The program is `target/release/deploy-ftp.exe` (just `deploy-ftp` on Linux/macOS). It is a single
file with no dependencies, so it can be copied anywhere, e.g. a folder on your PATH.
Or build and install it in one go with `cargo install --path .`.

## Use

```powershell
deploy-ftp --source bin/Publish --host ftp.example.com --user me --folder www/site
```

Build a .NET project and upload the result:

```powershell
deploy-ftp --publish src/MyApp/MyApp.csproj --source src/MyApp/bin/Publish --host ftp.example.com --user me --folder www/site
```

For Stavemester, from the repository root:

```powershell
cargo run --release --manifest-path tools/deploy-ftp/Cargo.toml -- --publish src/Stavemester/Stavemester.csproj --source src/Stavemester/bin/Publish --host ftp.example.com --user me --folder webroots/www/test
```

## Options

| Option | Environment variable | |
|---|---|---|
| `--source <DIR>` | `FTP_SOURCE` | Local folder whose contents are uploaded. Required. |
| `--host <HOST>` | `FTP_HOST` | FTP server, optionally with a port: `ftp.example.com:2121`. Port 21 by default. |
| `--user <USER>` | `FTP_USERNAME` | User name. |
| `--password <PASSWORD>` | `FTP_PASSWORD` | Password. If neither is given, you're asked for it (input hidden). |
| `--folder <PATH>` | `FTP_FOLDER` | Folder on the server, relative to the folder the login starts in. Created if missing. Default: the login folder. |
| `--publish <PROJECT>` | | Runs `dotnet publish -c Release -o <source> <project>` before uploading. **The source folder is deleted first**, so it must be a folder used only for publish output. |

The environment variable names match the GitHub secrets used by the workflow in this repository,
so the same values work in both places.

### About `--password`

A password on the command line ends up in your shell history and is visible to other programs
in the process list. Prefer, in this order:

1. leaving it out and typing it at the prompt,
2. `FTP_PASSWORD` set for the current session only: `$env:FTP_PASSWORD = '...'`,
3. `--password`.

## How it uploads

- Plain FTP (no TLS), passive mode, binary transfers.
- Every file is uploaded every time and existing files on the server are overwritten.
  Files on the server that no longer exist locally are left alone.
- Folders are created as needed.

For a sync that only sends changed files, see `scripts/Deploy-Ftp-Scp.ps1` (WinSCP) or the GitHub
Actions workflow.
