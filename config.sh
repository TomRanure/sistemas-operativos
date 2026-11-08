#!/bin/bash

DB_FILE="data.sq3"

LOG_SYSTEM="system.log"
LOG_ERROR="error.log"

MAX=3


#!/bin/bash

DB_FILE="data.sq3"
MAX=3

LOG_SYSTEM="system.log"
LOG_ERROR="error.log"

USUARIO_ACTIVO_ID=""
USUARIO_ACTIVO_NOMBRE=""

log_system() {
    local accion="$1"
    local fecha_hora

    fecha_hora=$(date "+%Y-%m-%d %H:%M:%S")

    printf "%s\tID: %s\tUsuario: %s\tAcción: %s\n" \
        "$fecha_hora" \
        "$USUARIO_ACTIVO_ID" \
        "$USUARIO_ACTIVO_NOMBRE" \
        "$accion" >> "$LOG_SYSTEM"
}

log_error() {
    local mensaje_error="$1"
    local fecha_hora

    fecha_hora=$(date "+%Y-%m-%d %H:%M:%S")

    printf "[%s] ERROR: %s\n" \
        "$fecha_hora" \
        "$mensaje_error" >> "$LOG_ERROR"
}
