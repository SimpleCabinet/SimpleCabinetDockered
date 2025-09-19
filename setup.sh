#!/bin/bash -e
set -e
FRONTEND_BRANCH=main
MODULE_BRANCH=support/5.7.x

SIMPLECABINET_REMOTE=localhost:17549
SIMPLECABINET_PROTOCOL=http

SIMPLECABINET_REMOTE_URL=$SIMPLECABINET_PROTOCOL:\\/\\/$SIMPLECABINET_REMOTE

echo -e "\033[32mPhase 0: \033[33mDownload repositories\033[m";

if ! [ -d frontend-src ]; then
    git clone --depth=1 -b $FRONTEND_BRANCH https://github.com/SimpleCabinet/SimpleCabinetFrontend.git frontend-src
fi

if ! [ -d module-src ]; then
    git clone --depth=1 -b $MODULE_BRANCH https://github.com/SimpleCabinet/SimpleCabinetModule.git module-src
fi

echo -e "\033[32mPhase 1: \033[33mBuild SimpleCabinet\033[m";

docker run --rm -v "$(pwd)/module-src:/app" -w /app -u $(id -u):$(id -g) eclipse-temurin:21-noble ./gradlew build

echo -e "\033[32mPhase 2: \033[33mBuild Docker containers\033[m";

sed -i "s/LAUNCHSERVER_ADDRESS_PLACEHOLDER/$SIMPLECABINET_REMOTE\/launcher/" docker-compose.yml || true
sed -i "s/SIMPLECABINET_REMOTE_URL_PLACEHOLDER/$SIMPLECABINET_REMOTE_URL\/userassets\//" docker-compose.yml || true
docker compose up -d --build

echo -e "\033[32mPhase 3: \033[33mSleep 60 seconds\033[m";

sleep 60

echo -e "\033[32mPhase 3.1: \033[33mRun basic initialization\033[m";

docker compose exec simplecabinet curl http://simplecabinet:8080/setup > setup.json
ADMIN_API_TOKEN=$(cat setup.json | jq ".accessToken")
docker compose cp module-src/build/libs/*.jar gravitlauncher:/app/data/SimpleCabinet_module.jar
echo "modules load SimpleCabinet_module.jar" | docker compose exec -T gravitlauncher socat UNIX-CONNECT:control-file -
docker compose restart gravitlauncher

echo -e "\033[32mPhase 3.2: \033[33mSleep 20 seconds\033[m";

sleep 20

echo -e "\033[32mPhase 3.3: \033[33mRun 'simplecabinet install' command\033[m";

echo "cabinet install http://simplecabinet:8080 $ADMIN_API_TOKEN" | docker compose exec -T gravitlauncher socat UNIX-CONNECT:control-file -

echo -e "\033[32mPhase 4: \033[33mInstallation complete\033[m";
