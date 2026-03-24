# Reproducible .NET Builds with Multi-Stage Docker

A reference project demonstrating how to achieve **reproducible builds** for .NET applications using multi-stage Docker containers. Two builds from the same source commit produce bit-for-bit identical images.

## Why Reproducible Builds?

Reproducible builds provide strong guarantees that the binary artifact was built from the declared source code — no hidden modifications, no build-time surprises. This strengthens supply chain security and makes it possible to verify that what runs in production matches what is in source control.

This project demonstrates the key techniques required to achieve this with .NET and Docker.

## How It Works

Reproducibility is achieved through a combination of tools and practices:

| Technique | Purpose |
|---|---|
| `SOURCE_DATE_EPOCH` | Pins all embedded timestamps to the latest git commit |
| [`DotNet.ReproducibleBuilds`](https://github.com/dotnet/reproducible-builds) | Enables deterministic compilation in the .NET SDK |
| NuGet lock files (`packages.lock.json`) | Locks the exact package versions and content hashes |
| `--provenance=false --sbom=false` | Disables Docker-generated metadata that varies between builds |

## Project Structure

```
├── Dockerfile                        # Multi-stage build definition
├── build.sh                          # Local build and verification script
├── .github/workflows/ci.yml          # GitHub Actions CI pipeline
└── src/
    ├── Sample.slnx                   # Solution file
    ├── Directory.Build.props         # Shared build properties (reproducibility settings)
    ├── Directory.Packages.props      # Centralized NuGet package versions
    ├── Sample.WebApi/                # ASP.NET Core Web API
    ├── Sample.Lib/                   # Shared class library
    └── Sample.WebApi.Tests/          # xUnit test project
```

## The Docker Build Pipeline

The `Dockerfile` defines multiple stages that enforce quality gates before producing the final image:

```
node_base
    └── spell_check          ← Spell-check all C# source files

build_base
    ├── verify_dotnet_format ← Enforce code formatting (dotnet format)
    └── build                ← Compile the solution + optional SonarQube analysis
            └── tests        ← Run xUnit tests
            └── tests.linux-x64    ← Export test results (scratch image)
            └── publish      ← Publish the Web API
                    └── files.linux-x64    ← Export binaries (scratch image)
                    └── runtime.linux-x64  ← Final production image
```

The production image is based on the [chiseled ASP.NET runtime](https://github.com/dotnet/dotnet-docker/blob/main/documentation/ubuntu-chiseled.md) — a minimal, distroless-style image that contains only what is needed to run the application.

## Getting Started

### Prerequisites

- Docker with BuildKit enabled (Docker 23+)
- Git

### Local Build

```bash
# Build and verify reproducibility
./build.sh
```

The script:
1. Extracts `SOURCE_DATE_EPOCH` from the latest git commit
2. Builds the production image twice (with slightly different args)
3. Compares the two images using [`diffoci`](https://github.com/reproducible-containers/diffoci) to confirm they are semantically identical

### Build a Single Target

```bash
export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)

# Run spell check only
docker build --target spell_check .

# Build the production image
docker build \
  --target runtime.linux-x64 \
  --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
  --provenance=false \
  --sbom=false \
  -t my-app:latest .
```

### Build with SonarQube Analysis

```bash
docker build \
  --target runtime.linux-x64 \
  --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
  --build-arg RUN_SONARQUBE=true \
  --secret id=SONAR_TOKEN,env=SONAR_TOKEN \
  --secret id=SONAR_ORGANIZATION,env=SONAR_ORGANIZATION \
  --secret id=SONAR_PROJECT_KEY,env=SONAR_PROJECT_KEY \
  --provenance=false \
  --sbom=false \
  -t my-app:latest .
```

## CI/CD Pipeline

The [GitHub Actions workflow](.github/workflows/ci.yml) runs on every push and pull request to `main`. It executes each quality gate stage in sequence and uploads test results and the application binaries as build artifacts.

**Caching strategy**: NuGet packages, npm packages, and .NET tools are all cached in the GitHub Actions cache, keyed by their respective lock files. This avoids re-downloading dependencies on every run while still invalidating the cache when versions change.

## Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `DotNet.ReproducibleBuilds` | 2.0.2 | Deterministic .NET compilation |
| `xunit` | 2.9.3 | Unit testing framework |
| `coverlet.collector` | 8.0.0 | Code coverage collection |
| `Microsoft.AspNetCore.OpenApi` | 10.0.3 | OpenAPI support |
| `cspell` (npm) | 9.7.0 | Source code spell checking |
| `dotnet-sonarscanner` | 11.2.0 | SonarQube analysis |

## Stack

- **.NET 10.0** — Target framework
- **ASP.NET Core** — Web API runtime
- **Docker BuildKit** — Multi-stage builds with layer caching and secret mounts
- **GitHub Actions** — CI/CD automation
- **SonarQube** — Static analysis and code quality

## Verifying Reproducibility

To confirm two builds produce identical images, the project uses [`diffoci`](https://github.com/reproducible-containers/diffoci):

```bash
./diffoci diff --semantic docker://tag1 docker://tag2
```

A clean output (no semantic differences) confirms the build is reproducible.
