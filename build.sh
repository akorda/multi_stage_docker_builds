SOURCE_DATE_EPOCH=$(git log -1 --pretty=%ct)
docker build --target tests.linux-x64 -f Dockerfile --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH --output type=tar,dest=tests.linux-x64.tar,rewrite-timestamp=false .
docker build --target files.linux-x64 -f Dockerfile --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH --output type=tar,dest=app.linux-x64.tar,rewrite-timestamp=false .
docker build --target runtime.linux-x64 -f Dockerfile --build-arg SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH .