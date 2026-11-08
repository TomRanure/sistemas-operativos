#!/usr/bin/env bash

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR" || exit 1

source "$PROJECT_DIR/api.sh"

vista_mensaje() {
    whiptail \
        --title "Sistema de inventario" \
        --msgbox "$1" 10 50
}


vista_mostrar_inventario() {

    local inventario=""

    if inventario=$(api_mostrar_inventario); then

        if [[ -z "$inventario" ]]; then
            whiptail \
                --title "Inventario" \
                --msgbox "No hay productos registrados." \
                8 45
        else
            whiptail \
                --title "Inventario de productos" \
                --msgbox "$inventario" \
                20 70
        fi

    else
        whiptail \
            --title "Error" \
            --msgbox "No se pudo consultar el inventario." \
            8 50
    fi
}

vista_alta_producto() {

    local id=""
    local nombre=""
    local precio=""

    id=$(whiptail \
        --title "Alta de producto" \
        --inputbox "Ingrese el ID del producto:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    nombre=$(whiptail \
        --title "Alta de producto" \
        --inputbox "Ingrese el nombre del producto:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi


    precio=$(whiptail \
        --title "Alta de producto" \
        --inputbox "Ingrese el precio del producto:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    if api_alta_producto "$id" "$nombre" "$precio"; then

        whiptail \
            --title "Alta exitosa" \
            --msgbox "El producto '$nombre' fue registrado correctamente." \
            10 50

    else

        whiptail \
            --title "Error" \
            --msgbox "No se pudo registrar el producto. Verifique los datos." \
            10 50

    fi
}

vista_baja_producto() {
    local id=""

    id=$(whiptail \
        --title "Baja de producto" \
        --inputbox "Ingrese el ID del producto:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    if whiptail --yesno "¿Está seguro de dar de baja el producto ID $id?" 10 55; then

        if api_baja_producto "$id"; then
            vista_mensaje "Producto dado de baja correctamente."
        else
            vista_mensaje "No se pudo dar de baja el producto."
        fi

    fi
}

vista_modificar_producto() {
    local id=""
    local nombre=""
    local precio=""

    id=$(whiptail --title "Modificar producto" \
        --inputbox "Ingrese el ID del producto:" 10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    nombre=$(whiptail --title "Modificar producto" \
        --inputbox "Ingrese el nuevo nombre:" 10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    precio=$(whiptail --title "Modificar producto" \
        --inputbox "Ingrese el nuevo precio:" 10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    if api_modificar_producto "$id" "$nombre" "$precio"; then
        vista_mensaje "Producto modificado correctamente."
    else
        vista_mensaje "No se pudo modificar el producto."
    fi
}

vista_generar_reporte() {

    if api_generar_reporte; then
        vista_mensaje "Reporte generado correctamente.\nArchivo: reporte.html"
    else
        vista_mensaje "No se pudo generar el reporte."
    fi
}

vista_registrar_usuario() {
    local usuario=""
    local contrasena=""

    usuario=$(whiptail \
        --title "Registro" \
        --inputbox "Ingrese un nombre de usuario:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    contrasena=$(whiptail \
        --title "Registro" \
        --passwordbox "Ingrese una contraseña:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    if api_registrar_usuario "$usuario" "$contrasena"; then
        vista_mensaje "Usuario registrado correctamente."
    else
        vista_mensaje "No se pudo registrar el usuario. Verifique los datos."
    fi
}


vista_iniciar_sesion() {
    local usuario=""
    local contrasena=""
    local resultado=""
    local usuario_id=""
    local usuario_nombre=""

    usuario=$(whiptail \
        --title "Inicio de sesión" \
        --inputbox "Ingrese su usuario:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    contrasena=$(whiptail \
        --title "Inicio de sesión" \
        --passwordbox "Ingrese su contraseña:" \
        10 50 \
        3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        return
    fi

    if resultado=$(api_iniciar_sesion "$usuario" "$contrasena"); then

        IFS='|' read -r usuario_id usuario_nombre <<< "$resultado"

	USUARIO_ACTIVO_ID="$usuario_id"
        USUARIO_ACTIVO_NOMBRE="$usuario_nombre"

        vista_mensaje "Bienvenido, $usuario_nombre."

        vista_menu_inventario "$usuario_id" "$usuario_nombre"

    else
        vista_mensaje "Usuario o contraseña incorrectos."
    fi
}


vista_menu_inventario() {
    local usuario_id="$1"
    local usuario_nombre="$2"
    local opcion=""

    while true; do

        opcion=$(whiptail \
            --title "Sistema de inventario" \
            --menu "Bienvenido, $usuario_nombre\nSeleccione una operación:" \
            18 60 6 \
            "1" "Dar de alta un producto" \
            "2" "Dar de baja un producto" \
            "3" "Mostrar inventario" \
            "4" "Modificar producto" \
            "5" "Generar reporte HTML" \
            "6" "Cerrar sesión" \
            3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]]; then
            return
        fi

        case "$opcion" in
        1)
        	vista_alta_producto
        	;;
    	2)
        	vista_baja_producto
        	;;
    	3)
        	vista_mostrar_inventario
        	;;
    	4)
        	vista_modificar_producto
        	;;
    	5)
        	vista_generar_reporte
        	;;
    	6)
    		 USUARIO_ACTIVO_ID=""
   		 USUARIO_ACTIVO_NOMBRE=""
                return
                ;;
        esac
    done
}

vista_menu_principal() {
    local opcion=""

    while true; do

        opcion=$(whiptail \
            --title "Sistema de inventario" \
            --menu "Seleccione una opción:" \
            15 55 3 \
            "1" "Iniciar sesión" \
            "2" "Registrarse" \
            "3" "Salir" \
            3>&1 1>&2 2>&3)

        if [[ $? -ne 0 ]]; then
            break
        fi

        case "$opcion" in
            1)
                vista_iniciar_sesion
                ;;
            2)
                vista_registrar_usuario
                ;;
            3)
                break
                ;;
        esac
    done

    whiptail \
        --title "Sistema de inventario" \
        --msgbox "¡Hasta pronto!" 8 40
}

main() {
    api_inicializar_base_de_datos
    vista_menu_principal
}

main
