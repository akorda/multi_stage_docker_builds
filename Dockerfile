FROM mcr.microsoft.com/dotnet/sdk:10.0.103 AS build

ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    NUGET_PACKAGES=/root/.nuget/packages
WORKDIR /build

# Copy root build files
COPY src/Directory.Build.props ./
COPY src/Directory.Packages.props ./

# --- Stage 1: Copy .csproj files only (for restore layer caching) ---

COPY src/Sample.WebApi/Sample.WebApi.csproj src/Sample.WebApi/Sample.WebApi.csproj
COPY src/Sample.WebApi/packages.lock.json src/Sample.WebApi/packages.lock.json

# --- Stage 2: Restore (cached unless .csproj files change) ---

RUN dotnet restore src/Sample.WebApi/Sample.WebApi.csproj --locked-mode

# --- Stage 3: Copy source code for required projects only ---

COPY src/Sample.WebApi/ src/Sample.WebApi/

# --- Stage 4: Build & Publish ---

RUN dotnet build src/Sample.WebApi/Sample.WebApi.csproj --no-restore -f net10.0 -c Release --runtime linux-x64
RUN dotnet build src/Sample.WebApi/Sample.WebApi.csproj --no-restore -f net10.0 -c Release --runtime win-x64
RUN dotnet publish src/Sample.WebApi/Sample.WebApi.csproj --no-restore --no-build -f net10.0 -c Release -o /app/linux-x64 --runtime linux-x64
RUN dotnet publish src/Sample.WebApi/Sample.WebApi.csproj --no-restore --no-build -f net10.0 -c Release -o /app/win-x64 --runtime win-x64

FROM scratch AS files.linux-x64
COPY --from=build /app/linux-x64/*.* ./

FROM mcr.microsoft.com/dotnet/aspnet:10.0.3-noble-chiseled-amd64 AS runtime.linux-x64
EXPOSE 8080
WORKDIR /app
COPY --from=build /app/linux-x64/*.* ./
ENTRYPOINT ["dotnet", "Sample.WebApi.dll"]