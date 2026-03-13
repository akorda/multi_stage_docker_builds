FROM mcr.microsoft.com/dotnet/sdk:10.0.201 AS build

ARG NUGET_PACKAGES=/root/.nuget/packages

ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    NUGET_PACKAGES=${NUGET_PACKAGES}

WORKDIR /build

# Copy root build files
COPY src/Directory.Build.props ./
COPY src/Directory.Packages.props ./

# --- Stage 1: Copy solution & .csproj/packages.lock.json files only (for restore layer caching) ---

COPY src/Sample.slnx src/Sample.slnx
COPY src/Sample.WebApi/Sample.WebApi.csproj src/Sample.WebApi/Sample.WebApi.csproj
COPY src/Sample.WebApi/packages.lock.json src/Sample.WebApi/packages.lock.json
COPY src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj
COPY src/Sample.WebApi.Tests/packages.lock.json src/Sample.WebApi.Tests/packages.lock.json

# --- Stage 2: Restore (cached unless .csproj files change) ---

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet restore src/Sample.slnx --locked-mode

# --- Stage 3: Copy source code for required projects only ---

COPY src/ src/

# --- Stage 4: Build & Publish ---

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet build src/Sample.WebApi/Sample.WebApi.csproj \
    --no-restore -f net10.0 -c Release --runtime linux-x64

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet build src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj \
    --no-restore -f net10.0 -c Release --runtime linux-x64

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet test src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj \
    --no-build -f net10.0 -c Release --runtime linux-x64 \
    --logger "html;logfilename=report.html"

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet publish src/Sample.WebApi/Sample.WebApi.csproj \
    --no-restore --no-build -f net10.0 -c Release -o /app/linux-x64 --runtime linux-x64

FROM scratch AS tests.linux-x64
COPY --from=build /build/src/Sample.WebApi.Tests/TestResults/*.* ./

FROM scratch AS files.linux-x64
COPY --from=build /app/linux-x64/*.* ./

FROM mcr.microsoft.com/dotnet/aspnet:10.0.5-noble-chiseled-amd64 AS runtime.linux-x64
EXPOSE 8080
WORKDIR /app
COPY --from=build /app/linux-x64/*.* ./
ENTRYPOINT ["dotnet", "Sample.WebApi.dll"]