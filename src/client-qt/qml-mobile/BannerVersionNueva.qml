// BannerVersionNueva.qml — aviso discreto y no bloqueante de que hay una
// versión más nueva publicada que la instalada (VersionChecker.hpp
// consulta la API de GitHub al arrancar, ver Main.qml). Mismo patrón visual
// que BannerInvitacionSala.qml, pero sin auto-descarte por tiempo -- es
// información de cortesía, no algo urgente que deba desaparecer solo.
pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: banner
    property string versionRemota: ""
    property string urlRelease: ""

    /// Muestra el banner con los datos de la versión detectada -- mismo
    /// patrón que BannerInvitacionSala.mostrar(). Sin auto-descarte: es
    /// información de cortesía, no algo urgente que deba desaparecer solo.
    function mostrar(version, url) {
        banner.versionRemota = version;
        banner.urlRelease = url;
        banner.visible = true;
    }

    visible: false

    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: 16 * Tema.escala
    z: 200
    width: Math.min(440 * Tema.escala, (parent ? parent.width : 440) - 40 * Tema.escala)
    height: filaBanner.height + 24 * Tema.escala
    radius: 10 * Tema.escala
    color: Tema.colorPanel
    border.width: 1
    border.color: Tema.colorAccent

    Row {
        id: filaBanner
        anchors.centerIn: parent
        width: parent.width - 24 * Tema.escala
        spacing: 12 * Tema.escala

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 12 * Tema.escala - botonesBanner.width
            wrapMode: Text.WordWrap
            text: "Hay una versión nueva disponible (v" + banner.versionRemota + ")"
            color: Tema.colorTexto
            font.pixelSize: 12 * Tema.escala
        }
        Row {
            id: botonesBanner
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * Tema.escala
            BotonRelleno {
                text: "Ver"
                onClicked: {
                    if (banner.urlRelease !== "") Qt.openUrlExternally(banner.urlRelease);
                }
            }
            BotonContorno {
                text: "Descartar"
                onClicked: banner.visible = false
            }
        }
    }
}
