//! Uploads a local folder to an FTP server, optionally running `dotnet publish` into it first.
//!
//!   deploy-ftp --source bin/Publish --host ftp.example.com --user me --folder www/site
//!
//! Each setting can instead come from an environment variable (FTP_HOST, FTP_USERNAME,
//! FTP_PASSWORD, FTP_FOLDER, FTP_SOURCE). The password is asked for if it isn't given.
//! See README.md.

use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Context, Result, bail};
use clap::Parser;
use suppaftp::types::FileType;
use suppaftp::{FtpStream, Mode};

#[derive(Parser)]
#[command(version, about = "Upload a folder to an FTP server, optionally running dotnet publish into it first")]
struct Args {
    /// Local folder whose contents are uploaded
    #[arg(long, env = "FTP_SOURCE")]
    source: PathBuf,

    /// FTP server, optionally with a port (ftp.example.com or ftp.example.com:2121)
    #[arg(long, env = "FTP_HOST")]
    host: String,

    #[arg(long, env = "FTP_USERNAME")]
    user: String,

    /// Password. Visible in the process list and shell history, so prefer FTP_PASSWORD or the prompt
    #[arg(long, env = "FTP_PASSWORD", hide_env_values = true)]
    password: Option<String>,

    /// Folder on the server to upload into, relative to the login folder, e.g. webroots/www/test
    #[arg(long, env = "FTP_FOLDER", default_value = "")]
    folder: String,

    /// .NET project to `dotnet publish -c Release` into --source first (the folder is emptied)
    #[arg(long)]
    publish: Option<PathBuf>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let password = match args.password.as_deref() {
        Some(password) if !password.is_empty() => password.to_string(),
        _ => rpassword::prompt_password(format!("FTP password for {}@{}: ", args.user, args.host))?,
    };

    let source = &args.source;
    if let Some(project) = &args.publish {
        publish(project, source)?;
    }

    let files = list_files(source)?;
    if files.is_empty() {
        bail!("Nothing to upload in {}", source.display());
    }

    let address = if args.host.contains(':') { args.host.clone() } else { format!("{}:21", args.host) };
    let mut ftp = FtpStream::connect(&address).with_context(|| format!("Could not connect to {address}"))?;
    ftp.set_mode(Mode::Passive);
    ftp.login(args.user.as_str(), password.as_str()).context("Login failed")?;
    ftp.transfer_type(FileType::Binary)?;

    let target = args.folder.trim_matches('/').replace('\\', "/");
    if !target.is_empty() {
        make_dirs(&mut ftp, &target);
        ftp.cwd(&target).with_context(|| format!("Could not open {target}"))?;
    }

    for (i, file) in files.iter().enumerate() {
        let relative = file.strip_prefix(source)?.to_string_lossy().replace('\\', "/");
        println!("[{}/{}] {relative}", i + 1, files.len());

        if let Some((folder, _)) = relative.rsplit_once('/') {
            make_dirs(&mut ftp, folder);
        }
        let mut reader = BufReader::new(File::open(file)?);
        ftp.put_file(&relative, &mut reader).with_context(|| format!("Upload of {relative} failed"))?;
    }

    ftp.quit()?;
    println!("Uploaded {} files to ftp://{}/{target}", files.len(), args.host);
    Ok(())
}

/// Runs `dotnet publish` into a clean output folder (the folder is deleted first).
fn publish(project: &Path, publish_dir: &Path) -> Result<()> {
    let project_full = project.canonicalize().with_context(|| format!("Project {} not found", project.display()))?;
    if publish_dir.exists() {
        // Guard against e.g. `--source .`, which would delete the project itself.
        if project_full.starts_with(publish_dir.canonicalize()?) {
            bail!("--source {} contains the project; publish into a separate folder", publish_dir.display());
        }
        std::fs::remove_dir_all(publish_dir)?;
    }
    let status = Command::new("dotnet")
        .args(["publish", "-c", "Release", "-o"])
        .arg(publish_dir)
        .arg(project)
        .status()
        .context("Could not run dotnet")?;
    if !status.success() {
        bail!("dotnet publish failed");
    }
    Ok(())
}

/// All files below `dir`, in a stable order.
fn list_files(dir: &Path) -> Result<Vec<PathBuf>> {
    let mut files = Vec::new();
    let mut pending = vec![dir.to_path_buf()];
    while let Some(current) = pending.pop() {
        for entry in std::fs::read_dir(&current).with_context(|| format!("Could not read {}", current.display()))? {
            let path = entry?.path();
            if path.is_dir() { pending.push(path) } else { files.push(path) }
        }
    }
    files.sort();
    Ok(files)
}

/// Creates each folder on a relative path, one level at a time.
/// MKD fails when a folder already exists, which is fine, so errors are ignored.
fn make_dirs(ftp: &mut FtpStream, path: &str) {
    let mut current = String::new();
    for part in path.split('/').filter(|p| !p.is_empty()) {
        if !current.is_empty() {
            current.push('/');
        }
        current.push_str(part);
        let _ = ftp.mkdir(&current);
    }
}
