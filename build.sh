export SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)

# docker build \
#     --target verify_dotnet_format \
#     -f Dockerfile \
#     --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
#     .

# docker build \
#     --target tests.linux-x64 \
#     -f Dockerfile \
#     --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
#     --output type=tar,dest=tests.linux-x64.tar,rewrite-timestamp=false .

# docker build \
#     --target files.linux-x64 \
#     -f Dockerfile \
#     --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
#     --output type=tar,dest=app.linux-x64.tar,rewrite-timestamp=false \
#     .

docker build \
    --target spell_check \
    -f Dockerfile \
    .

docker build \
    --no-cache \
    --target runtime.linux-x64 \
    -f Dockerfile \
    --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
    --provenance=false \
    --sbom=false \
    -t tag1 \
    .

docker build \
    --no-cache \
    --target runtime.linux-x64 \
    -f Dockerfile \
    --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH \
    --build-arg SKIP_DOTNET_FORMAT=true \
    --provenance=false \
    --sbom=false \
    -t tag2 \
    .

# wget -q -O diffoci https://github.com/reproducible-containers/diffoci/releases/download/v0.1.8/diffoci-v0.1.8.linux-amd64
# chmod +x ./diffoci
./diffoci diff --semantic docker://tag1 docker://tag2
