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

inicializar_archivo(){
	if [[ ! -f productos.tsv ]]; then
	touch productos.tsv
	printf "Archivo productos.tsv creado.\n"
	fi
}

inicializar_usuarios(){
	if [[ ! -f usuarios.tsv ]]; then
	touch usuarios.tsv
	printf "Archivo usuarios fue creado.\n"
	fi
}

seleccionar_registro() {

	declare -i opc=0

 	printf "1. Inciar sesion.\n"
	printf "2. Registrar usuario.\n"

	read -rp "Ingrese una opcion: " opc

	if (( opc < 1 || opc > 2 )); then
	printf "Ingrese una opcion correcta (1-2)"
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
    declare usuario_archivo=""
    declare hash_archivo=""

    read -rp "Ingrese un usuario: " usuario
    read -rsp "Ingrese una contraseña: " contrasena
    printf "\n"


    while IFS=$'\t' read -r usuario_archivo hash_archivo; do

        if [[ "$usuario" == "$usuario_archivo" ]]; then
            printf "Error: el usuario ya existe.\n"
            return 1
        fi

    done < usuarios.tsv

    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')

    printf "%s\t%s\n" "$usuario" "$hash" >> usuarios.tsv

    printf "Usuario registrado correctamente.\n"

    return 0

}

iniciar_sesion() {

    declare usuario=""
    declare contrasena=""
    declare hash=""
    declare usuario_archivo=""
    declare hash_archivo=""

    read -rp "Ingrese usuario: " usuario
    read -rsp "Ingrese contraseña: " contrasena
    printf "\n"

 
    hash=$(printf "%s" "$contrasena" | sha256sum | awk '{print $1}')


    while IFS=$'\t' read -r usuario_archivo hash_archivo; do

        if [[ "$usuario" == "$usuario_archivo" ]]; then

            if [[ "$hash" == "$hash_archivo" ]]; then
                printf "Inicio de sesión correcto.\n"
                return 0
            else
                printf "Contraseña incorrecta.\n"
                return 1
            fi

        fi

    done < usuarios.tsv

    printf "El usuario no existe.\n"
    return 1

}

alta() {
    declare -i id=$1
    declare -n prod_ref=$2 


    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        return
    fi

    if [[ ${inventario[$id,activo]:-0} -eq 1 ]]; then
        printf "Error: el producto ya existe.\n"
        return 1
    fi

    inventario[$id,precio]=${prod_ref[precio]}
    inventario[$id,nombre]=${prod_ref[nombre]}
    inventario[$id,activo]=${prod_ref[activo]}

    printf "Ya se guardo el producto con id %d y nombre %s con precio $%.2f.\n" "$id" "${prod_ref[nombre]}" "${prod_ref[precio]}"
}

baja() {
    declare -i id=$1

    if (( id < 0 || id >= MAX )); then
        printf "Error: ID fuera de rango.\n"
        return
    fi

    if [[ ${inventario[$id,activo]} -eq 1 ]]; then
        inventario[$id,activo]=0
        printf "Producto %d eliminado.\n" "$id"
    else
        printf "El producto no existe.\n"
    fi
}

mostrar() {
    declare -i i=0

    printf "\nLISTADO:\n"
    for ((i=0; i<MAX; i++)); do
        if [[ ${inventario[$i,activo]} -eq 1 ]]; then
            printf "ID: %d -  Nombre: %s - Precio: $%.2f\n" "$i" "${inventario[$i,nombre]}" "${inventario[$i,precio]}"
        fi
    done
}

modificar() {

    declare -i id=$1
    declare  nombre_nuevo=""
    declare -i precio_nuevo=0

    if (( id < 0 || id >= MAX )); then
    printf"Error: ID fuera de rango. \n"
    return

    fi

    read -rp "Ingrese nuevo nombre del producto: " nombre_nuevo
    read -rp "Ingrese nuevo precio del producto: " precio_nuevo

    inventario[$id,nombre]=$nombre_nuevo
    inventario[$id,precio]=$precio_nuevo
 
    printf "Producto %d modificado correctamente.\n" "$id"
}

reporte(){
declare i=0

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
                <th>
                    ID
                </th>
                <th>
                    Nombre 
                </th>
                <th>
                    Precio
                </th>
            </tr>
EOF
    for ((i=0;i<MAX;i++)); do
    if [[ ${inventario[$i,activo]} -eq 1 ]]; then

    cat <<EOF >> reporte.html  
   <tr>
	<td>$i</td>
	<td>${inventario[$i,nombre]}</td>
	<td>${inventario[$i,precio]}</td>
   </tr>
EOF
     fi
    done
cat <<EOF >> reporte.html
    </table>
</body>
</html>
EOF

echo "¡El archivo reporte.html ha sido creado correctamente!"
}

cargar_inventario(){
	while IFS=$'\t' read -r id nombre precio activo; do
	[[ "$id" == "ID" ]] && continue
	inventario[$id,nombre]=$nombre
	inventario[$id,precio]=$precio
   	inventario[$id,activo]=$activo

	done < productos.tsv
}

guardar_inventario() {

    printf "ID\tNOMBRE\tPRECIO\tACTIVO\n" > productos.tsv

    for ((i=0; i<MAX; i++)); do

        printf "%d\t%s\t%s\t%s\n" \
            "$i" \
            "${inventario[$i,nombre]}" \
            "${inventario[$i,precio]}" \
            "${inventario[$i,activo]}" \
            >> productos.tsv

    done
}

main() {
    declare -i i=0

    for ((i=0; i<MAX; i++)); do
        inventario[$i,activo]=0
        inventario[$i,precio]=0
        inventario[$i,nombre]=""
    done

	while true; do
    	seleccionar_registro

    	resultado=$?

    	if (( resultado == 0 )); then
        break
    fi
	done

    inicializar_archivo
    cargar_inventario
    inicializar_usuarios

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
                alta "$id" p_temp
		guardar_inventario
                ;;
            $OPCION_BAJA)
                read -rp "Ingrese ID a eliminar (0-$((MAX - 1))): " id
                baja "$id"
                guardar_inventario
                ;;
            $OPCION_MOSTRAR)
                mostrar
                ;;
	    $OPCION_MODIFICAR)
                read -rp "Ingrese ID (0-$((MAX - 1))): " id
                modificar "$id"
		guardar_inventario
                ;;
	    $REPORTE_HTML)
                reporte
                ;;
            $OPCION_SALIR)
                printf "\nSaliendo del programa...\n"
                guardar_inventario
                ;;
            *)
                printf "\nOpcion invalida.\n"
                ;;
        esac
    done

    return 0
}

main
