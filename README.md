# ReVanced Extended Builder

A modern, structured build system for creating ReVanced modules and APKs with automated CI/CD workflows.

## ✨ Features

- **🏗️ Modern Architecture**: Clean, modular codebase with separation of concerns
- **🔄 Automated CI/CD**: GitHub Actions workflows for continuous integration and deployment
- **🛡️ Security-First**: Built-in security scanning and dependency reviews
- **📱 Multi-Platform**: Support for ARM64, ARM32, and universal architectures
- **🔧 Flexible Configuration**: TOML/JSON configuration with extensive customization options
- **🚀 Parallel Builds**: Efficient multi-threaded building process
- **📦 Multiple Sources**: Support for APKMirror, Uptodown, and archive downloads
- **🔄 Auto-Updates**: Automatic configuration updates and Magisk module metadata

## 🚀 Quick Start

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install jq openjdk-21-jre zip curl

# Other dependencies are downloaded automatically
```

### Basic Usage

```bash
# Build with default configuration
./build.sh

# Build with custom configuration
./build.sh custom-config.toml

# Clean build environment
./build.sh clean

# Check for configuration updates
./build.sh --config-update

# Show help
./build.sh --help
```

## 📋 Configuration

The build system uses TOML or JSON configuration files. Here's a basic example:

```toml
# Main configuration
compression-level = 9
parallel-jobs = 4
patches-source = "ReVanced/revanced-patches"
cli-source = "j-hc/revanced-cli"
rv-brand = "ReVanced"
enable-magisk-update = true

# App configuration
[YouTube]
enabled = true
app-name = "YouTube"
apkmirror-dlurl = "https://www.apkmirror.com/apk/google-inc/youtube/"
arch = "arm64-v8a"
build-mode = "both"
excluded-patches = ["Shorts shelf", "Hide shorts"]
include-stock = true

[YouTube Music]
enabled = true
app-name = "YouTube Music"
uptodown-dlurl = "https://youtube-music.en.uptodown.com/android"
arch = "all"
build-mode = "module"
```

## 🏗️ Architecture

### Project Structure

```
revanced-extended/
├── .github/workflows/          # CI/CD workflows
│   ├── ci.yml                 # Continuous integration
│   ├── build.yml              # Build workflow
│   ├── release.yml            # Release management
│   ├── security.yml           # Security scanning
│   └── reusable-setup.yml     # Reusable setup tasks
├── build.sh                   # Main build script
├── utils.sh                   # Utility functions
├── config.toml                # Default configuration
└── revanced-magisk/           # Magisk module template
```

### Workflow Overview

1. **CI Workflow** (`ci.yml`): Detects changes and triggers builds
2. **Build Workflow** (`build.yml`): Compiles ReVanced modules and APKs
3. **Release Workflow** (`release.yml`): Creates GitHub releases and updates metadata
4. **Security Workflow** (`security.yml`): Automated security scanning

## 🔧 Advanced Configuration

### Build Modes

- `apk`: Build non-root APK only
- `module`: Build Magisk module only  
- `both`: Build both APK and module

### Architecture Support

- `arm64-v8a`: ARM64 devices
- `arm-v7a`: ARM32 devices
- `all`: Universal (includes both architectures)
- `both`: Separate builds for each architecture

### Download Sources

- **APKMirror**: `apkmirror-dlurl`
- **Uptodown**: `uptodown-dlurl`
- **Archive**: `archive-dlurl` (direct file hosting)

### Patch Management

```toml
[App]
included-patches = ["Patch 1", "Patch 2"]     # Only include these patches
excluded-patches = ["Unwanted patch"]         # Exclude these patches
exclusive-patches = true                      # Use only included patches
```

## 🛠️ Development

### Custom Build Steps

The build process follows these steps:

1. **Environment Setup**: Dependencies validation and tool setup
2. **Configuration Loading**: Parse TOML/JSON configuration
3. **Parallel Processing**: Build apps concurrently based on configuration
4. **Architecture Handling**: Split builds for different architectures
5. **Artifact Generation**: Create APKs and Magisk modules
6. **Release Management**: Upload to GitHub and update metadata

## 🔐 Security

### Automated Security Scanning

- **Trivy**: Filesystem vulnerability scanning
- **ShellCheck**: Shell script analysis
- **Dependency Review**: Automated dependency vulnerability checks
- **Scheduled Scans**: Weekly security assessments

### Code Quality

- **Structured Error Handling**: Comprehensive error reporting
- **Input Validation**: Strict parameter validation
- **Safe Defaults**: Secure default configurations
- **Clean Architecture**: Modular, maintainable codebase

## 📈 Monitoring & Logging

### Build Logs

- Comprehensive logging with emojis for readability
- Structured error reporting
- GitHub Actions integration for CI/CD visibility
- Telegram notifications (optional)

### Metrics

- Build duration tracking
- Success/failure rates
- Parallel job efficiency
- Resource utilization

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing code style
4. Test thoroughly
5. Submit a pull request

### Code Style

- Use structured functions with clear purposes
- Add comprehensive error handling
- Include logging for debugging
- Follow existing naming conventions
- Document complex logic

## 📄 License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## 🙏 Acknowledgments

- ReVanced Team for the excellent patching framework
- Contributors to the original build scripts
- Community feedback and testing

## 🐛 Troubleshooting

### Common Issues

**Build fails with "missing dependencies"**
```bash
# Install required packages
sudo apt update && sudo apt install jq openjdk-21-jre zip curl
```

**Permission denied errors**
```bash
# Make scripts executable
chmod +x build.sh utils.sh
```

**Configuration errors**
```bash
# Validate configuration syntax
./build.sh --config-update
```

### Getting Help

- Check the [Issues](https://github.com/thunderkex/revanced-extended/issues) page
- Review build logs for error details
- Ensure all dependencies are installed
- Verify configuration file syntax

---

**Made with ❤️ for the ReVanced community**
