FROM mcr.microsoft.com/dotnet/sdk:10.0.201 AS build_base

ARG NUGET_PACKAGES=/root/.nuget/packages
ARG SOURCE_DATE_EPOCH=0
ARG SONARSCANNER_VERSION=11.2.0
ARG RUN_SONARQUBE=false

ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    NUGET_PACKAGES=${NUGET_PACKAGES} \
    SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH} \
    PATH="$PATH:/root/.dotnet/tools"

WORKDIR /build

# Copy root build files
COPY src/Directory.Build.props ./
COPY src/Directory.Packages.props ./
# Copy solution & .csproj/packages.lock.json files only
COPY src/Sample.slnx src/Sample.slnx
COPY src/Sample.WebApi/Sample.WebApi.csproj src/Sample.WebApi/Sample.WebApi.csproj
COPY src/Sample.WebApi/packages.lock.json src/Sample.WebApi/packages.lock.json
COPY src/Sample.Lib/Sample.Lib.csproj src/Sample.Lib/Sample.Lib.csproj
COPY src/Sample.Lib/packages.lock.json src/Sample.Lib/packages.lock.json
COPY src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj
COPY src/Sample.WebApi.Tests/packages.lock.json src/Sample.WebApi.Tests/packages.lock.json

# Restore (cached unless previous files changed)
RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet restore src/Sample.slnx --locked-mode

# Copy source code
COPY src/ src/

# Verify no-format errors
FROM build_base AS verify_dotnet_format
COPY .editorconfig ./
RUN dotnet format src/Sample.slnx \
    --verify-no-changes

# Build
FROM build_base AS build

RUN if [ $RUN_SONARQUBE = true ]; then \
    dotnet tool install --global dotnet-sonarscanner --version $SONARSCANNER_VERSION; \
    fi

RUN --mount=type=secret,id=sonarqube_org,env=SONARQUBE_ORG \
    --mount=type=secret,id=sonarqube_project_key,env=SONARQUBE_PROJECT_KEY \
    --mount=type=secret,id=sonarqube_token,env=SONARQUBE_TOKEN \
    if [ $RUN_SONARQUBE = true ]; then \
    dotnet sonarscanner begin \
    /o:$SONARQUBE_ORG \
    /k:$SONARQUBE_PROJECT_KEY \
    /d:sonar.token=$SONARQUBE_TOKEN; \
    fi

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet build src/Sample.WebApi/Sample.WebApi.csproj \
    --no-restore -f net10.0 -c Release --runtime linux-x64

RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet build src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj \
    --no-restore -f net10.0 -c Release --runtime linux-x64

RUN --mount=type=secret,id=sonarqube_token,env=SONARQUBE_TOKEN \
    if [ $RUN_SONARQUBE = true ]; then \
    dotnet sonarscanner end \
    /d:sonar.token=$SONARQUBE_TOKEN; \
    fi

# Run tests
FROM build AS tests
RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet test src/Sample.WebApi.Tests/Sample.WebApi.Tests.csproj \
    --no-build -f net10.0 -c Release --runtime linux-x64 \
    --logger "html;logfilename=report.html"

FROM scratch AS tests.linux-x64
COPY --from=tests /build/src/Sample.WebApi.Tests/TestResults/*.* ./

FROM build AS publish
RUN --mount=type=cache,target=$NUGET_PACKAGES \
    dotnet publish src/Sample.WebApi/Sample.WebApi.csproj \
    --no-restore --no-build -f net10.0 -c Release -o /app/linux-x64 --runtime linux-x64

# Save binaries
FROM scratch AS files.linux-x64
COPY --from=publish /app/linux-x64/*.* ./

# Create docker image
FROM mcr.microsoft.com/dotnet/aspnet:10.0.5-noble-chiseled-amd64 AS runtime.linux-x64
EXPOSE 8080
WORKDIR /app
COPY --from=publish /app/linux-x64/*.* ./
ENTRYPOINT ["dotnet", "Sample.WebApi.dll"]
