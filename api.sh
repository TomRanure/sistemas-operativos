#!/bin/bash

source ./model.sh

api_inicializar_base_de_datos() {
    	model_inicializar_base_de_datos
}

api_registrar_usuario() {
    	local nombre="$1"
    	local contrasena="$2"

    	model_registrar_usuario "$nombre" "$contrasena"
}

api_iniciar_sesion() {
    	local usuario="$1"
    	local contrasena="$2"

    	model_iniciar_sesion "$usuario" "$contrasena"
}

api_mostrar_inventario() {
    	model_mostrar_inventario
}

api_alta_producto() {
	local id="$1"
    	local nombre="$2"
    	local precio="$3"
	model_alta_producto "$1" "$2" "$3"
}

api_baja_producto() {
	local id="$1"
	model_baja_producto "$id"
}

api_modificar_producto() {
	local id="$1"
    	local nombre="$2"
    	local precio="$3"

    	model_modificar_producto "$id" "$nombre" "$precio"
}

api_generar_reporte() {
	model_generar_reporte
}
