#!/bin/bash

source ./config.sh

model_inicializar_base_de_datos() {
    if [ ! -f "$DB_FILE" ]; then
        echo " El archivo '$DB_FILE' no existe. Creando e inicializando..."

       sqlite3 "$DB_FILE" <<-EOF
        CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL UNIQUE,
            contrasena VARCHAR (150)
        );

	CREATE TABLE IF NOT EXISTS productos (
	    id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre_producto TEXT NOT NULL,
	    precio_producto REAL  NOT NULL,
	    activo_producto INTEGER
	);
EOF

        if [ $? -eq 0 ]; then
            echo " Base de datos '$DB_FILE' inicializada con éxito."
        else
            echo "Error: No se pudo inicializar la base de datos." >&2
            log_error "No se pudo inicializar la base de datos sqlite3."
	    return 1
        fi
    else
        echo " El archivo '$DB_FILE' ya existe. No se realizaron cambios."
    fi
}

model_mostrar_inventario() {

    if sqlite3 -column -header "$DB_FILE" "
        SELECT
            id AS 'ID',
            nombre_producto AS 'Nombre',
            precio_producto AS 'Precio ($)'
        FROM productos
        WHERE activo_producto = 1;
    "; then

        log_system "Consultó el inventario de productos"
        return 0

    else

        log_error "Error al ejecutar consulta SELECT de listado"
        return 1

    fi
}

model_registrar_usuario() {
    local usuario="$1"
    local contrasena="$2"
    local hash=""

    if [[ -z "$usuario" ]] || [[ -z "$contrasena" ]]; then
        log_error "Intento de registro fallido: Campos vacíos"
        return 1
    fi

    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')

    sqlite3 "$DB_FILE" <<-EOF
    INSERT INTO usuarios (nombre, contrasena)
    VALUES ('$usuario', '$hash');
EOF

    if [ $? -eq 0 ]; then
        return 0
    else
        log_error "Error al insertar el usuario '$usuario' en la base de datos"
        return 1
    fi
}

model_iniciar_sesion() {
    local usuario="$1"
    local contrasena="$2"
    local hash=""
    local resultado=""

    if [[ -z "$usuario" || -z "$contrasena" ]]; then
        log_error "Intento de inicio de sesión con campos vacíos"
        return 1
    fi

    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')

    resultado=$(sqlite3 -separator '|' "$DB_FILE" \
        "SELECT id, nombre FROM usuarios
         WHERE nombre='$usuario' AND contrasena='$hash'
         LIMIT 1;")

    if [[ -z "$resultado" ]]; then
        log_error "Inicio de sesión fallido para '$usuario'"
        return 1
    fi

    printf '%s\n' "$resultado"
    return 0
}

model_alta_producto() {
    declare -i id="$1"
    local nombre="$2"
    local precio="$3"
    local existe=""

    if (( id < 0 || id >= MAX )); then
        log_error "Alta fallida: ID $id fuera de rango (MAX: $MAX)"
        return 1
    fi

    if [[ -z "$nombre" || -z "$precio" ]]; then
        log_error "Alta fallida: Campos vacíos"
        return 1
    fi

    existe=$(sqlite3 "$DB_FILE" \
        "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")

    if (( existe > 0 )); then
        log_error "Alta fallida: El producto ID $id ya existe de forma activa"
        return 1
    fi

    if ! sqlite3 "$DB_FILE" <<EOF
INSERT INTO productos
(id, nombre_producto, precio_producto, activo_producto)
VALUES ($id, '$nombre', $precio, 1);
EOF
    then
        log_error "Alta fallida: Error de inserción SQLite para ID $id"
        return 1
    fi

    log_system "Alta exitosa de producto ID $id ($nombre)"
    return 0
}


model_baja_producto() {
    declare -i id="$1"
    declare -i existe=0

    if (( id < 0 || id >= MAX )); then
        log_error "Baja fallida: ID $id fuera de rango"
        return 1
    fi

    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")

    if [[ $existe -eq 1 ]]; then

        if sqlite3 "$DB_FILE" "UPDATE  productos SET activo_producto = 0 WHERE id = $id;"; then
            log_system "Baja exitosa de producto ID $id"
            return 0
        else
            log_error "Baja fallida: Error de UPDATE SQLite en ID $id"
            return 1
        fi

    else
        log_error "Baja fallida: El producto ID $id no existe de forma activa"
        return 1
    fi
}

model_modificar_producto() {
    declare -i id="$1"
    declare nombre_nuevo="$2"
    declare precio_nuevo="$3"
    declare -i existe=0

    if (( id < 0 || id >= MAX )); then
        log_error "Modificación fallida: ID $id fuera de rango"
        return 1
    fi

    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")

    if [[ $existe -eq 0 ]]; then
        log_error "Modificación fallida: ID $id no activo o inexistente"
        return 1
    fi

    if [[ -z "$nombre_nuevo" ]] || [[ -z "$precio_nuevo" ]]; then
        log_error "Modificación fallida: Campos vacíos para ID $id"
        return 1
    fi

    if [[ ! "$precio_nuevo" =~ ^[0-9]+([.][0-9]{1,2})?$ ]]; then
        log_error "Modificación fallida: Precio inválido para ID $id"
        return 1
    fi

    if sqlite3 "$DB_FILE" "
        UPDATE productos
        SET nombre_producto = '$nombre_nuevo',
            precio_producto = $precio_nuevo
        WHERE id = $id AND activo_producto = 1;
    "; then

        log_system "Modificación exitosa de producto ID $id (Nuevo: $nombre_nuevo)"
        return 0

    else
        log_error "Modificación fallida: Error de UPDATE SQLite para ID $id"
        return 1
    fi
}

model_generar_reporte() {
    local archivo="reporte.html"

    cat << 'EOF' > "$archivo"
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ARCHIVO DE REPORTE</title>
</head>
<body>
    <h1>Reporte de inventario</h1>
    <table>
        <tr>
            <th>ID</th>
            <th>Nombre</th>
            <th>Precio</th>
        </tr>
EOF

    if ! sqlite3 "$DB_FILE" "
        SELECT printf(
            '        <tr>\n            <td>%d</td>\n            <td>%s</td>\n            <td>$%.2f</td>\n        </tr>',
            id, nombre_producto, precio_producto
        )
        FROM productos
        WHERE activo_producto = 1;
    " >> "$archivo"; then

        log_error "Error al exportar reporte.html mediante SQLite"
        return 1
    fi

    cat << 'EOF' >> "$archivo"
    </table>
</body>
</html>
EOF

    if [[ $? -eq 0 ]]; then
        log_system "Generó reporte HTML"
        return 0
    else
        log_error "Error al finalizar reporte.html"
        return 1
    fi
}
