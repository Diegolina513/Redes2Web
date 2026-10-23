#!/usr/bin/env bash
# Ejecutar como root en la instancia EC2.
set -Eeuo pipefail

IMAGE="diegolina513/redes2web:latest"
NAME="redes2web"
CANDIDATE="redes2web-candidate"
BACKUP="redes2web-backup"
PUBLIC_PORT=3300

exec 9>/run/lock/redes2web-deploy.lock
flock -n 9 || exit 0

docker pull "$IMAGE"
TARGET_ID=$(docker image inspect "$IMAGE" --format '{{.Id}}')
CURRENT_ID=$(docker inspect "$NAME" --format '{{.Image}}' 2>/dev/null || true)
if [[ "$TARGET_ID" == "$CURRENT_ID" ]] && [[ $(docker inspect "$NAME" --format '{{.State.Running}}') == true ]]; then
    echo "Sin cambios: $TARGET_ID"
    exit 0
fi

docker rm -f "$CANDIDATE" >/dev/null 2>&1 || true
trap 'docker rm -f "$CANDIDATE" >/dev/null 2>&1 || true' EXIT
docker run -d --name "$CANDIDATE" -p 127.0.0.1::5000 "$TARGET_ID"
CANDIDATE_PORT=$(docker inspect "$CANDIDATE" --format '{{(index (index .NetworkSettings.Ports "5000/tcp") 0).HostPort}}')
curl --fail --silent --show-error --retry 15 --retry-all-errors --retry-delay 2 "http://127.0.0.1:$CANDIDATE_PORT/"

OLD_NAME=""
if docker inspect "$NAME" >/dev/null 2>&1; then
    OLD_NAME="$NAME"
elif docker inspect prueba >/dev/null 2>&1; then
    # Migracion inicial del contenedor existente de la practica.
    OLD_NAME=prueba
fi

if [[ -n "$OLD_NAME" ]]; then
    docker rm -f "$BACKUP" >/dev/null 2>&1 || true
    docker stop "$OLD_NAME"
    docker rename "$OLD_NAME" "$BACKUP"
fi

rollback() {
    echo 'Fallo del despliegue. Restaurando version anterior.' >&2
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    if [[ -n "$OLD_NAME" ]]; then
        docker rename "$BACKUP" "$OLD_NAME"
        docker start "$OLD_NAME"
    fi
}

if ! docker run -d --name "$NAME" --restart unless-stopped \
    --log-opt max-size=10m --log-opt max-file=3 \
    -p "$PUBLIC_PORT:5000" "$TARGET_ID"; then
    rollback
    exit 1
fi
if ! curl --fail --silent --show-error --retry 15 --retry-all-errors --retry-delay 2 "http://127.0.0.1:$PUBLIC_PORT/"; then
    rollback
    exit 1
fi
echo "Despliegue correcto: $TARGET_ID en puerto $PUBLIC_PORT"
