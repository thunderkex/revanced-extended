use anyhow::Result;
use clap::{Parser, Subcommand};
use revancex::{builder, config, module, orchestrator, pages, utils};
use tracing_subscriber::EnvFilter;

#[derive(Parser)]
#[command(
    name = "revancex",
    version,
    about = "Modern ReVanced patcher with dynamic configuration",
    long_about = None
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,

    #[arg(short, long, global = true)]
    verbose: bool,

    #[arg(short, long, global = true, default_value = "./config")]
    config_dir: String,
}

#[derive(Subcommand)]
enum Commands {
    Apps {
        #[arg(short, long)]
        json: bool,
    },

    Build {
        #[arg(short, long, default_value = "all")]
        apps: String,

        #[arg(long, default_value = "arm64-v8a")]
        arch: String,

        #[arg(short, long, default_value = "full")]
        mode: String,

        #[arg(short, long, default_value = "./output")]
        output: String,

        #[arg(long)]
        force: bool,
    },

    Module {
        #[arg(long)]
        single: bool,

        #[arg(long)]
        bundle: bool,

        #[arg(short, long, default_value = "all")]
        apps: String,

        #[arg(long)]
        include_webui: bool,

        #[arg(short, long, default_value = "./modules")]
        output: String,
    },

    CheckUpdates {
        #[arg(short, long)]
        json: bool,
    },

    GenerateMatrix {
        #[arg(short, long, default_value = "all")]
        apps: String,

        #[arg(long, default_value = "all")]
        arch: String,

        #[arg(short, long, default_value = "auto")]
        mode: String,
    },

    Validate {
        #[arg(short, long)]
        strict: bool,
    },

    Clean {
        #[arg(long)]
        all: bool,
    },

    DownloadTools,

    GenAppsJson,

    FetchApk {
        app: String,
        #[arg(long, default_value = "arm64-v8a")]
        arch: String,
    },

    VerifyModule {
        zip: String,
    },
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::from_default_env().add_directive(if cli.verbose {
                "debug".parse()?
            } else {
                "info".parse()?
            }),
        )
        .with_writer(std::io::stderr)
        .init();

    let config = config::load_config(&cli.config_dir)?;

    match cli.command {
        Commands::Apps { json } => {
            orchestrator::list_apps(&config, json).await?;
        }

        Commands::Build {
            apps,
            arch,
            mode,
            output,
            force,
        } => {
            orchestrator::build_apps(&config, &apps, &arch, &mode, &output, force).await?;
        }

        Commands::Module {
            single,
            bundle,
            apps,
            include_webui,
            output,
        } => {
            if single {
                module::single::build_single_module(&config, &apps, &output).await?;
            }
            if bundle {
                module::bundle::build_bundle_module(&config, &apps, include_webui, &output).await?;
            }
        }

        Commands::CheckUpdates { json } => {
            orchestrator::check_updates(&config, json).await?;
        }

        Commands::GenerateMatrix { apps, arch, mode } => {
            orchestrator::generate_matrix(&config, &apps, &arch, &mode).await?;
        }

        Commands::Validate { strict } => {
            config::validate_config(&config, strict)?;
        }

        Commands::Clean { all } => {
            utils::cache::clean_cache(all)?;
        }

        Commands::DownloadTools => {
            utils::download_tools(&config).await?;
        }

        Commands::GenAppsJson => {
            let json = pages::generate_apps_json(&config)?;
            std::fs::create_dir_all("docs")?;
            std::fs::write("docs/apps.json", &json)?;
            println!("docs/apps.json written ({} bytes)", json.len());
        }

        Commands::FetchApk { app, arch } => {
            let app_cfg = config
                .apps
                .get(&app)
                .ok_or_else(|| anyhow::anyhow!("Unknown app: {app}"))?;
            std::fs::create_dir_all(&config.build.temp_dir)?;
            let path = builder::fetch_apk(&config, &app, app_cfg, &arch).await?;
            let size = std::fs::metadata(&path)?.len();
            println!("SUCCESS: {app} downloaded to {path} ({size} bytes)");
        }

        Commands::VerifyModule { zip } => {
            module::verify_bundle(&zip)?;
            println!("SUCCESS: Magisk/KernelSU module {zip} is valid and ready for installation!");
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use clap::CommandFactory;

    #[test]
    fn verify_cli() {
        Cli::command().debug_assert();
    }
}
