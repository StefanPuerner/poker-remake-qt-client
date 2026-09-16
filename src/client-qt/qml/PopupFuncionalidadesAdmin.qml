// PopupFuncionalidadesAdmin.qml — herramientas de administración/QA,
// reunidas en un único popup (pedido explícito 2026-09-16: antes vivían
// sueltas, en línea, dentro de Cuenta > Perfil). Se abre con un botón
// "Funcionalidades Admin" -- SOLO visible para cuentas con es_admin=1
// (AccountManager::esAdmin(), se marca a mano en la base). Escritorio
// únicamente, como el resto de esta herramienta (ver CLAUDE.md: "decisión
// ya tomada de NO portarla a móvil").
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Popup {
    id: popup
    parent: Overlay.overlay
    anchors.centerIn: parent
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(420 * Tema.escala, (parent ? parent.width : 420) - 60 * Tema.escala)
    padding: 20 * Tema.escala

    property string servidorHost
    property int servidorPuerto
    property string tokenSesion

    property string mensajeExportacion: ""
    property string mensajeConceder: ""
    property string mensajeFabricar: ""
    property bool confirmandoBorrarPrueba: false
    property string mensajeBorrarPrueba: ""

    /// Limpia todo mensaje/confirmación pendiente de una apertura anterior
    /// antes de mostrarse -- mismo criterio de reset-al-reentrar que ya
    /// usaba Cuenta al volver a esta pestaña.
    function abrir() {
        mensajeExportacion = "";
        mensajeConceder = "";
        mensajeFabricar = "";
        mensajeBorrarPrueba = "";
        confirmandoBorrarPrueba = false;
        popup.open();
    }

    Connections {
        target: redcliente
        // Fase 1 del sistema de progresión -- herramienta de estadísticas
        // mínima.
        function onEstadisticasExportadas(archivo) {
            popup.mensajeExportacion = "Exportado a data/" + archivo + " en el servidor.";
        }
        function onEstadisticasExportadasError(mensaje) {
            popup.mensajeExportacion = mensaje;
        }
        // Conceder marco/logro/objeto (ver AccountManager::adminConcederItem()).
        function onAdminConcederOk(mensaje) {
            popup.mensajeConceder = mensaje;
            // Mismo motivo que onObjetoEquipado() en Main.qml -- si te lo
            // has concedido a ti mismo, sin esto el resultado no se ve
            // hasta salir y volver a entrar en Cuenta. Barato/inofensivo
            // pedirlo también al conceder a OTRA cuenta.
            redcliente.consultarLoadout(popup.servidorHost, popup.servidorPuerto, popup.tokenSesion);
            redcliente.consultarTienda(popup.servidorHost, popup.servidorPuerto, popup.tokenSesion);
            redcliente.consultarEstadisticas(popup.servidorHost, popup.servidorPuerto, popup.tokenSesion);
        }
        function onAdminConcederError(mensaje) {
            popup.mensajeConceder = mensaje;
        }
        // Fabricar cuentas de prueba.
        function onAdminFabricarOk(mensaje) {
            popup.mensajeFabricar = mensaje;
        }
        function onAdminFabricarError(mensaje) {
            popup.mensajeFabricar = mensaje;
        }
        // Eliminar cuentas de prueba.
        function onAdminBorrarPruebaOk(mensaje) {
            popup.mensajeBorrarPrueba = mensaje;
            popup.confirmandoBorrarPrueba = false;
        }
        function onAdminBorrarPruebaError(mensaje) {
            popup.mensajeBorrarPrueba = mensaje;
            popup.confirmandoBorrarPrueba = false;
        }
    }

    background: Rectangle {
        color: Tema.colorPanel
        radius: 12 * Tema.escala
        border.width: 1
        border.color: Tema.colorAccent
    }

    contentItem: Column {
        spacing: 16 * Tema.escala
        width: popup.width - popup.padding * 2

        Text {
            width: parent.width
            text: Idioma.t("titulo_funcionalidades_admin")
            color: Tema.colorTexto
            font.family: Tema.fuenteElegante
            font.bold: true
            font.pixelSize: 16 * Tema.escala
        }

        // ── Fase 1: herramienta de estadísticas mínima ──────────────────
        Column {
            width: parent.width
            spacing: 6 * Tema.escala
            BotonContorno {
                width: parent.width
                text: Idioma.t("boton_exportar_estadisticas")
                onClicked: {
                    popup.mensajeExportacion = "texto_exportando";
                    redcliente.exportarEstadisticas(popup.servidorHost, popup.servidorPuerto, popup.tokenSesion);
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: popup.mensajeExportacion !== ""
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: Idioma.t(popup.mensajeExportacion)
            }
        }

        // ── Conceder marco/logro/objeto -- un único campo de código para
        // los tres (el servidor decide cuál de los tres es, ver el
        // comentario de adminConcederItem() en AccountManager.hpp).
        // Reemplaza al antiguo botón dedicado "Conceder marco Hierro"
        // (pedido explícito 2026-09-16: "mejor implementa codigos para
        // los marcos y se asignan igual que los logros/objetos") --
        // ahora Bronce/Plata/Oro/Platino también se pueden forzar, no
        // solo Hierro.
        Column {
            width: parent.width
            spacing: 6 * Tema.escala
            Text {
                text: Idioma.t("admin_titulo_conceder")
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                font.letterSpacing: 0.5
            }
            CampoTexto {
                id: campoAdminUsername
                width: parent.width
                font.pixelSize: 13 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : Idioma.t("placeholder_username_destino")
                onAccepted: campoAdminCodigo.forceActiveFocus()
            }
            CampoTexto {
                id: campoAdminCodigo
                width: parent.width
                font.pixelSize: 13 * Tema.escala
                placeholderText: (activeFocus || text.length > 0) ? "" : Idioma.t("placeholder_codigo_logro_objeto")
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: Idioma.t("ayuda_codigos_marco")
                color: Tema.colorTextoMuyTenue
                font.pixelSize: 10 * Tema.escala
            }
            BotonContorno {
                width: parent.width
                text: Idioma.t("boton_conceder")
                onClicked: {
                    if (campoAdminUsername.text.length === 0 || campoAdminCodigo.text.length === 0) {
                        popup.mensajeConceder = "error_admin_rellena_campos";
                        return;
                    }
                    popup.mensajeConceder = "texto_concediendo";
                    redcliente.adminConcederItem(popup.servidorHost, popup.servidorPuerto, popup.tokenSesion,
                                                  campoAdminUsername.text, campoAdminCodigo.text);
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: popup.mensajeConceder !== ""
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: Idioma.t(popup.mensajeConceder)
            }
        }

        // ── Fabricar cuentas de prueba -- MVP a propósito: un botón fijo
        // (15) en vez de un campo de cantidad más que rellenar.
        Column {
            width: parent.width
            spacing: 6 * Tema.escala
            BotonContorno {
                width: parent.width
                text: Idioma.t("boton_fabricar_cuentas_prueba")
                onClicked: {
                    popup.mensajeFabricar = "texto_fabricando";
                    redcliente.adminFabricarCuentasPrueba(popup.servidorHost, popup.servidorPuerto,
                                                           popup.tokenSesion, 15);
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: popup.mensajeFabricar !== ""
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: Idioma.t(popup.mensajeFabricar)
            }
        }

        // ── Eliminar cuentas de prueba -- pedido explícito 2026-09-16.
        // Irreversible, así que exige DOS pulsaciones (mismo patrón ya
        // usado para borrar una partida guardada, ver "🗑"/
        // boton_confirmar_borrado en Main.qml) en vez de fiarse de un
        // solo clic.
        Column {
            width: parent.width
            spacing: 6 * Tema.escala
            BotonContorno {
                width: parent.width
                colorBorde: Tema.colorPeligro
                text: popup.confirmandoBorrarPrueba ? Idioma.t("boton_confirmar_borrado")
                                                     : Idioma.t("boton_eliminar_cuentas_prueba")
                onClicked: {
                    if (popup.confirmandoBorrarPrueba) {
                        popup.mensajeBorrarPrueba = "texto_eliminando_cuentas_prueba";
                        redcliente.adminBorrarCuentasPrueba(popup.servidorHost, popup.servidorPuerto,
                                                             popup.tokenSesion);
                    } else {
                        popup.confirmandoBorrarPrueba = true;
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                visible: popup.mensajeBorrarPrueba !== ""
                color: Tema.colorTextoTenue
                font.pixelSize: 11 * Tema.escala
                text: Idioma.t(popup.mensajeBorrarPrueba)
            }
        }
    }
}
