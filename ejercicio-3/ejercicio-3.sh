#!/usr/bin/env bash

declare -r -i MAX=3
declare -A inventario

declare -r -i OPCION_ALTA=1
declare -r -i OPCION_BAJA=2
declare -r -i OPCION_MOSTRAR=3
declare -r -i OPCION_MODIFICAR=4
declare -r -i REPORTE_HTML=5
declare -r -i OPCION_SALIR=6

bienvenida() {
    printf "Bienvenido/a al sistema\n\n"
}

LOG_SYSTEM="system.log"
LOG_ERROR="error.log"

USUARIO_ACTIVO_ID=""
USUARIO_ACTIVO_NOMBRE=""

log_system() {
    declare accion="$1"
    declare fecha_hora
    fecha_hora=$(date "+%Y-%m-%d %H:%M:%S")
    printf "%s\t%s\t%s\t%s\n" "$fecha_hora"  "ID: $USUARIO_ACTIVO_ID" "$USUARIO_ACTIVO_NOMBRE" "$accion" >> "$LOG_SYSTEM"
}

log_error() {
    declare mensaje_error="$1"
    declare fecha_hora
    fecha_hora=$(date "+%Y-%m-%d %H:%M:%S")
    printf "[%s] ERROR: %s\n" "$fecha_hora" "$mensaje_error" >> "$LOG_ERROR"
}

DB_FILE="data.sq3"

inicializar_base_de_datos() {
    if [ ! -f "$DB_FILE" ]; then
        echo " El archivo '$DB_FILE' no existe. Creando e inicializando..."

       sqlite3 "$DB_FILE" <<-EOF
        CREATE TABLE IF NOT EXISTS usuarios (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
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

seleccionar_registro() {

	declare -i opc=0

 	printf "1. Inciar sesion.\n"
	printf "2. Registrar usuario.\n"

	read -rp "Ingrese una opcion: " opc

	if (( opc < 1 || opc > 2 )); then
	printf "Ingrese una opcion correcta (1-2)"
        log_error "Selección de registro/login inválida: Opcion $opc"
	return 1
	fi

	if (( opc == "1" )); then
	iniciar_sesion
        return $?
	fi

	if (( opc == "2" )); then
	registrar_usuario
	return 2
	fi
}

registrar_usuario() {
    declare usuario=""
    declare contrasena=""
    declare hash=""

    read -rp "Ingrese un usuario: " usuario
    read -rsp "Ingrese una contraseña: " contrasena
    printf "\n"

    if [[ -z "$usuario" ]] || [[ -z "$contrasena" ]]; then
        printf "Error: El usuario y la contraseña no pueden estar vacíos.\n"
	log_error "Intento de registro fallido: Campos vacíos"
        return 1
    fi

    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')


    sqlite3 data.sq3  <<EOF
    INSERT INTO usuarios (nombre, contrasena)
    VALUES ('$usuario', '$hash');
EOF

    if [ $? -eq 0 ]; then
        printf "Usuario registrado correctamente.\n"
        return 0
    else
        printf "Error: no se pudo registrar el usuario.\n"
	log_error "Error al insertar el usuario '$usuario' en la base de datos"
        return 1
    fi
}

iniciar_sesion() {
    declare usuario=""
    declare contrasena=""
    declare hash=""
    declare hash_db=""

    read -rp "Ingrese usuario: " usuario
    read -rsp "Ingrese contraseña: " contrasena
    printf "\n"

    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')
    hash_db=$(sqlite3 "$DB_FILE" "SELECT contrasena  FROM usuarios WHERE nombre = '$usuario';")

    id_db=$(sqlite3 "$DB_FILE" "SELECT id FROM usuarios WHERE nombre = '$usuario';")

    if [[ -z "$hash_db" ]]; then
        printf "El usuario no existe.\n"
        log_error "Intento de inicio de sesión con usuario inexistente: $usuario"
        return 1
    fi

    if [[ "$hash" == "$hash_db" ]]; then
        printf "Inicio de sesión correcto.\n"
	USUARIO_ACTIVO_ID="$id_db"
        USUARIO_ACTIVO_NOMBRE="$usuario"
        log_system "Inicio de sesión exitoso"
        return 0
    else
        printf "Contraseña incorrecta.\n"
	log_error "Contraseña incorrecta para el usuario: $usuario"
        return 1
    fi
}

alta_producto() {
    declare -i id=$1
    declare -n prod_ref=$2
    declare -i existe=0

    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        log_error "Alta fallida: ID $id fuera de rango (MAX: $MAX)"
	return 1
    fi

    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")
    if [[ $existe -gt 0 ]]; then
        printf "Error: el producto con ID %d ya existe.\n" "$id"
	log_error "Alta fallida: El producto ID $id ya existe de forma activa"
        return 1
    fi

    sqlite3 "$DB_FILE" <<-EOF
    INSERT OR REPLACE INTO productos (id, nombre_producto, precio_producto, activo_producto)
    VALUES ($id, '${prod_ref[nombre]}', ${prod_ref[precio]}, ${prod_ref[activo]});
EOF

    if [ $? -eq 0 ]; then
        printf "Ya se guardo el producto con id %d y nombre %s con precio \$%.2f en la base de datos.\n" "$id" "${prod_ref[nombre]}" "${prod_ref[precio]}"
        log_system "Alta exitosa de producto ID $id (${prod_ref[nombre]})"
	return 0
    else
        printf "Error: No se pudo escribir en la base de datos.\n"
	log_error "Alta fallida: Error de inserción SQLite para ID $id"
	return 1
    fi
}

baja_producto() {
    declare -i id=$1
    declare -i existe=0

    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        log_error "Baja fallida: ID $id fuera de rango"
        return 1
    fi

    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")
    
    if [[ $existe -eq 1 ]]; then
        sqlite3 "$DB_FILE" "UPDATE productos SET activo_producto = 0 WHERE id = $id;"
        if [ $? -eq 0 ]; then
            printf "Producto %d eliminado de la DB.\n" "$id"
            log_system "Baja exitosa de producto ID $id"
            return 0
        else
            log_error "Baja fallida: Error de UPDATE SQLite en ID $id"
            return 1
        fi
    else
        printf "El producto no existe o ya está dado de baja.\n"
        log_error "Baja fallida: El producto ID $id no existe de forma activa"
        return 1
    fi
}

mostrar_inventario() {
    printf "\n=== INVENTARIO DE PRODUCTOS ===\n"
    sqlite3 -column -header "$DB_FILE" "SELECT id AS 'ID', nombre_producto AS 'Nombre', precio_producto AS 'Precio (\$)' FROM productos WHERE activo_producto = 1;"

    if [ $? -eq 0 ]; then
        log_system "Visualizó el inventario en consola"
        printf "================================\n"
        return 0
    else
        log_error "Error al ejecutar consulta SELECT de listado"
        return 1
    fi
}

modificar_producto() {
    declare -i id=$1
    declare nombre_nuevo=""
    declare precio_nuevo=""
    declare -i existe=0


    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
	log_error "Modificacion fallida: ID $id fuera de rango"
        return 1
    fi


    existe=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM productos WHERE id = $id AND activo_producto = 1;")

    if [[ $existe -eq 0 ]]; then
        printf "Error: El producto con ID %d no existe o está dado de baja.\n" "$id"
        log_error "Modificacion fallida: ID $id no activo o inexistente"
	return 1
    fi

    read -rp "Ingrese nuevo nombre del producto: " nombre_nuevo
    read -rp "Ingrese nuevo precio del producto: " precio_nuevo

    if [[ -z "$nombre_nuevo" ]] || [[ -z "$precio_nuevo" ]]; then
        printf "Error: El nombre y el precio no pueden estar vacíos.\n"
        log_error "Modificación fallida: Campos vacíos provistos para ID $id"
	return 1
    fi

    sqlite3 "$DB_FILE" "UPDATE productos SET nombre_producto = '$nombre_nuevo', precio_producto = $precio_nuevo WHERE id = $id;"

    if [ $? -eq 0 ]; then
        printf "Producto %d modificado correctamente en la base de datos.\n" "$id"
        log_system "Modificación exitosa de producto ID $id (Nuevo: $nombre_nuevo)"
	return 0
    else
        printf "Error: No se pudieron actualizar los datos en la DB.\n"
        log_error "Modificación fallida: Error de UPDATE SQLite para ID $id"
	return 1
    fi
}

reporte_producto(){
    cat << 'EOF' > reporte.html
<!DOCTYPE html>
<html lang="en">
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

    sqlite3 "$DB_FILE" "SELECT printf('        <tr>\n            <td>%d</td>\n            <td>%s</td>\n            <td>$%.2f</td>\n        </tr>', id, nombre_producto, precio_producto) FROM productos WHERE activo_producto = 1;" >> reporte.html

    cat << 'EOF' >> reporte.html
    </table>
</body>
</html>
EOF

    if [ $? -eq 0 ]; then
        echo "¡El archivo reporte.html ha sido creado correctamente!"
        log_system "Generó reporte HTML"
    else
        log_error "Error al exportar reporte.html mediante SQLite"
    fi
}

main() {
	inicializar_base_de_datos

	while true; do
    	seleccionar_registro

    	resultado=$?

    	if (( resultado == 0 )); then
        break
    fi
	done

    bienvenida

    printf "\n"

    declare opcion=0
    declare -i id=0
    declare -A p_temp

    while [[ "$opcion" != "$OPCION_SALIR" ]]; do
        printf "\nACCIONES:\n"
        printf "1. Alta producto (ID 0 a %d)\n" $((MAX - 1))
        printf "2. Baja producto\n"
        printf "3. Mostrar inventario\n"
	printf "4. Modificar producto\n"
        printf "5. Reporte html\n"
        printf "6. Salir\n"
        read -rp "Opcion: " opcion

        case $opcion in
            $OPCION_ALTA)
                read -rp "Ingrese ID (0-$((MAX - 1))): " id
                read -rp "Ingrese un nombre: " p_temp[nombre]
                read -rp "Ingrese Precio: " p_temp[precio]
                p_temp[activo]=1

                alta_producto "$id" p_temp
                ;;
            $OPCION_BAJA)
                read -rp "Ingrese ID a eliminar (0-$((MAX - 1))): " id
                baja_producto "$id"
                ;;
            $OPCION_MOSTRAR)
                mostrar_inventario
                ;;
	    $OPCION_MODIFICAR)
                read -rp "Ingrese ID (0-$((MAX - 1))): " id
                modificar_producto "$id"
                ;;
	    $REPORTE_HTML)
                reporte_producto
                ;;
            $OPCION_SALIR)
                printf "\nSaliendo del programa...\n"
                ;;
            *)
                printf "\nOpcion invalida.\n"
                ;;
        esac
    done

    return 0
}

main
