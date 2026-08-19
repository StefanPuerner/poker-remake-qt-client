// EstadoOverlays.qml — registro del overlay modal abierto en cada momento
// (CampoEmergente hoy; el panel de chat/historial más adelante). Con
// varias pantallas cada una con sus propios popups, manejarAtras() en
// Main.qml no puede conocer cada instancia por su id a mano — en su lugar,
// cada overlay se registra aquí al abrirse y se desregistra al cerrarse, y
// manejarAtras() solo pregunta "¿hay algo abierto?" sin saber de qué
// pantalla es. Ver Parte 7 del plan de diseño móvil, punto 3.
pragma Singleton
import QtQuick

QtObject {
    property var popupActivo: null
}
