# Manual de usuario para técnicos — App "Servicios - SMPC"

**Servicios Main PC** · App móvil para reportes de servicio técnico de impresoras Zebra

> **Cómo leer este manual**
> - Los textos entre comillas (por ejemplo, "Crear reporte") son exactamente como aparecen en la pantalla.
> - Los marcadores `[CAPTURA NN: …]` indican dónde va una imagen. La lista completa está al final.
> - Los marcadores `[VERIFICAR]` aparecen solo en la sección final **"Pendientes de confirmar"**: son puntos que el equipo de Servicios Main PC debe confirmar antes de repartir este manual.
> - Este manual solo describe lo que la app hace hoy. No incluye funciones que todavía no están terminadas.

---

## Contenido

1. [Introducción](#1-introducción)
2. [Primer uso](#2-primer-uso)
3. [Mapa de navegación](#3-mapa-de-navegación)
4. [Guía por pantalla](#4-guía-por-pantalla)
5. [Flujos completos de principio a fin](#5-flujos-completos-de-principio-a-fin)
6. [Trabajo sin conexión y sincronización](#6-trabajo-sin-conexión-y-sincronización)
7. [Códigos y glosario](#7-códigos-y-glosario)
8. [Solución de problemas frecuentes](#8-solución-de-problemas-frecuentes)
9. [Lista de capturas](#lista-de-capturas)
10. [Pendientes de confirmar](#pendientes-de-confirmar)

---

## 1. Introducción

### ¿Qué es la app?

"Servicios - SMPC" es la aplicación que usas en el sitio del cliente para documentar cada servicio que haces a una impresora de etiquetas Zebra. Funciona **con o sin internet**: todo lo que captures se guarda primero en tu teléfono y se envía al servidor cuando hay conexión.

### ¿Para qué sirve?

- Identificar una impresora escaneando su código QR o buscando su número de serie.
- Llenar el reporte de servicio: tipo de servicio, contador, revisión técnica, fotos y observaciones.
- Recabar la firma del cliente.
- Generar el PDF del reporte.
- Consultar clientes, impresoras, historial de servicios y pólizas.
- Hacer entregas de pólizas de mantenimiento (varios equipos con una sola firma del cliente).
- Enviar tus reportes al servidor (sincronizar).

### Requisitos

| Requisito | Detalle |
|---|---|
| Teléfono o tableta | Android 7.0 (API 24) o superior. |
| Cámara | Necesaria para escanear el QR y tomar fotos de evidencia. |
| Permiso de cámara | La app lo solicita cuando lo necesita. Debes aceptarlo. |
| Permiso de fotos/archivos | Se usa solo si eliges fotos de la galería. |
| Internet | **Obligatorio para iniciar sesión** y para sincronizar. Para capturar reportes no es necesario. |
| Usuario y contraseña | Te los da el administrador. |
| Reloj del teléfono | Debe tener fecha y hora correctas (la sesión se valida con el reloj del teléfono). |

---

## 2. Primer uso

### 2.1 Instalar el APK

1. Recibe el archivo **APK** de la app (por correo, memoria USB o enlace que te dé tu supervisor). Confirma con tu supervisor que es la versión vigente (ver "Pendientes de confirmar").
2. Copia el archivo a tu teléfono si no lo descargaste directamente ahí.
3. Toca el archivo APK desde el administrador de archivos.
4. Si Android lo pide, permite **instalar aplicaciones de esta fuente** y regresa.
5. Toca **Instalar** y espera a que termine.
6. Abre la app. En el menú de aplicaciones se llama **"Servicios - SMPC"**.
7. Cuando la app pida permiso de cámara, toca **Permitir**.

### 2.2 Iniciar sesión

Necesitas internet para iniciar sesión.

1. Abre la app. Aparece la pantalla de inicio de sesión.
2. En **"Correo Electrónico o ID de Técnico"** escribe tu correo o tu ID de técnico.
3. En **"Contraseña"** escribe tu contraseña.
4. Toca **"INICIAR SESIÓN"**.
5. Al entrar llegas al **Panel principal**.

`[CAPTURA 01: Pantalla de inicio de sesión vacía, con logo, campos y botón "INICIAR SESIÓN"]`

En la parte inferior de la pantalla hay una tarjeta que dice cómo está la información local. Mientras la app descarga catálogos, el botón dice **"Sincronizando..."** y está desactivado (puede tardar hasta 10 segundos). Espera a que vuelva a decir "INICIAR SESIÓN".

`[CAPTURA 02: Tarjeta inferior del inicio de sesión en dos estados: "Sincronizando datos..." y "Sin conexión al servidor"]`

Si se equivocan los datos o no hay conexión, aparece un mensaje en la parte baja de la pantalla (ver sección 4.1).

`[CAPTURA 03: Mensaje de error al iniciar sesión (SnackBar) con credenciales incorrectas]`

> **Importante:** una vez que iniciaste sesión, la app **recuerda tu sesión**. La próxima vez que la abras entrarás directo al Panel principal, incluso sin internet. Tu sesión **no se cierra sola mientras uses la app**: dura hasta 365 días y se renueva cada vez que sincronizas con éxito. Solo se te pedirá iniciar sesión de nuevo si el administrador desactiva tu usuario o revoca tu sesión, o si pasa más de un año sin sincronizar (en ese caso la app sigue abriendo, pero no podrá sincronizar hasta que vuelvas a iniciar sesión; ver sección 8). **En ningún caso se borran tus reportes ni lo pendiente de enviar.**

### 2.3 Cerrar sesión

1. En el Panel principal, toca tu **nombre** o el **ícono de persona** (arriba a la izquierda). Se abre **"Mi Perfil"**.
2. Desplázate hasta abajo.
3. Toca **"CERRAR SESIÓN"**.
4. Si tienes elementos pendientes de sincronizar, la app muestra el aviso **"¿Cerrar sesión?"** con el número de pendientes y te dice que se conservan en el teléfono. Toca **"Cerrar sesión"** para continuar o **"Cancelar"** para quedarte.
5. La app regresa a la pantalla de inicio de sesión.

`[CAPTURA 04: Pantalla "Mi Perfil" completa, con el botón "CERRAR SESIÓN" y la leyenda inferior visible]`

`[CAPTURA 58: Aviso "¿Cerrar sesión?" con el número de elementos pendientes y los botones "Cancelar" y "Cerrar sesión"]`

> **Cerrar sesión no borra tus datos.** Tus reportes, fotos, firmas, catálogos y todo lo pendiente de sincronizar **se conservan en el teléfono**; solo se borran la sesión (tus credenciales) y el reporte que estuvieras capturando en ese momento. Debajo del botón la app lo recuerda: *"Al cerrar sesión se conservan tus reportes y los pendientes de sincronizar en este teléfono."*
>
> - Cuando vuelvas a iniciar sesión con **tu mismo usuario**, lo pendiente se envía en la siguiente sincronización.
> - Si **otro técnico** inicia sesión en el mismo teléfono, **no se envían tus pendientes con su sesión**: se quedan esperando a que tú vuelvas a iniciar sesión (el Centro de Sincronización avisa cuántos son de otro técnico).

---

## 3. Mapa de navegación

Todo parte del **Panel principal**. En todas las pantallas puedes regresar con la flecha de la parte superior o con el botón "atrás" de Android.

### 3.1 Tabla de pantallas

| # | Pantalla (título en la app) | Cómo llegar |
|---|---|---|
| 1 | Inicio de sesión | Se abre al instalar o al cerrar sesión. |
| 2 | Panel principal | Al iniciar sesión. Es la pantalla de inicio. |
| 3 | Mi Perfil | Panel principal → tu nombre o el ícono de persona. |
| 4 | Identificar Impresora | Panel principal → **"Escanear QR"**. |
| 5 | Confirmar Equipo | Identificar Impresora → escanea un QR, busca un serial o toca un resultado. |
| 6 | Captura de Servicio | Confirmar Equipo → **"Crear reporte"** (también desde Impresoras, Detalle de Cliente, Ficha Técnica o Nueva Impresora). |
| 7 | Resumen del Reporte | Captura de Servicio → **"Revisar Reporte"**. |
| 8 | Firma de Conformidad | Resumen del Reporte → **"Proceder a Firma"** o **"Guardar reporte"**. |
| 9 | Servicio registrado / Entrega registrada | Al terminar de guardar un reporte, una firma grupal o una entrega. |
| 10 | Firma grupal | Panel principal → botón **"Cerrar y firmar (N)"**; o Reportes → "Grupos abiertos"; o Confirmar Equipo → **"Firmar (N)"**. |
| 11 | Reportes | Panel principal → **"Reportes"**. |
| 12 | Ver Reporte (detalle de reporte) | Reportes, Detalle de Cliente, Ficha Técnica, Historial de Servicios, Entrega o Resumen de visita → tocar un reporte o **"Ver Reporte"**. |
| 13 | Visor de fotos | Ver Reporte → tocar una foto. |
| 14 | Clientes | Panel principal → **"Clientes"**. |
| 15 | Nuevo Cliente / Sitio · Editar Cliente | Clientes → botón **+**; o Detalle de Cliente → menú ⋮ → "Editar Cliente". |
| 16 | Detalle de Cliente | Clientes → tocar un cliente. |
| 17 | Impresoras (inventario) | Panel principal → **"Impresoras"**. |
| 18 | Nueva Impresora | Identificar Impresora → **"Crear Nueva Impresora"**; Impresoras → **"Agregar Impresora"**; Detalle de Cliente → **"Nueva"**. |
| 19 | Ficha Tecnica | Confirmar Equipo → **"Ver detalle"**; Impresoras → **"Ver detalle"**; Detalle de Cliente → **"Ver Detalles"**. |
| 20 | Historial de Servicios | Ficha Tecnica → **"Ver Historial"**. |
| 21 | Pólizas | Panel principal → **"Polizas"**. |
| 22 | Detalle de Póliza | Pólizas → tocar una póliza; o Detalle de Cliente → pestaña Polizas → tocar una póliza. |
| 23 | Entrega de póliza (carrusel de equipos; el título es el folio de la póliza) | Pólizas → **"Iniciar entrega"** o **"VER RESUMEN (N reportes)"**; también desde Detalle de Póliza. |
| 24 | Firma de entrega (título "Firma — folio") | Entrega de póliza → botón **"FIRMAR ENTREGA…"**. |
| 25 | Resumen de visita (título "Resumen — folio") | Entrega registrada → **"Ver resumen de visita"**; o Detalle de Póliza → pestaña Visitas → **"Ver resumen"**. |
| 26 | Centro de Sincronización | Panel principal → **"Por Sync"** o **"Ir a Sincronizar"**. |
| 27 | Historial de Sincronización | Centro de Sincronización → ícono de reloj (arriba a la derecha). |

### 3.2 Diagrama simplificado

```
Panel principal
├── Mi Perfil (tu nombre / ícono)
├── Escanear QR → Identificar Impresora → Confirmar Equipo → Captura de Servicio
│        → Resumen del Reporte → Firma de Conformidad → Servicio registrado
├── Por Sync → Centro de Sincronización → Historial de Sincronización
├── Clientes → Detalle de Cliente → (Impresoras | Polizas | Reportes)
├── Polizas → Detalle de Póliza → (Mis Tareas | Parque Total | Visitas)
│        └── Iniciar entrega → Firma de entrega → Entrega registrada → Resumen de visita
├── Impresoras → Ficha Tecnica → Historial de Servicios
└── Reportes → (Recientes | Grupos abiertos | Póliza activa) → Ver Reporte
```

---

## 4. Guía por pantalla

### 4.1 Inicio de sesión

**Para qué sirve:** identificarte con tu cuenta. **Cómo se llega:** al abrir la app por primera vez o después de cerrar sesión.

**Elementos de la pantalla**

| Elemento | Qué hace |
|---|---|
| Logo y texto "Field Service Management" | Solo informativo. |
| "Correo Electrónico o ID de Técnico" | Escribe tu correo o tu ID de técnico. Obligatorio. |
| "Contraseña" | Tu contraseña (se muestra con puntos). Obligatorio. |
| "INICIAR SESIÓN" | Envía tus datos. Se desactiva y muestra un círculo mientras valida. Si hay una sincronización en curso, dice "Sincronizando..." y no se puede tocar. |
| "¿Olvidaste tu contraseña? Contacta a soporte" | Muestra el aviso *"Contacta a soporte para restablecer tu contraseña."* La app no restablece contraseñas. |
| Tarjeta inferior de estado | Ver tabla siguiente. |
| "Forzar Sync" | Vuelve a intentar la descarga de datos. Dice "En curso" mientras trabaja. |

**Estados de la tarjeta inferior**

| Título | Subtítulo | Significado |
|---|---|---|
| "Sincronizando datos..." | "Descargando catálogos del servidor" | La app está descargando clientes, impresoras, pólizas, etc. |
| "Base de Datos Local: Lista" | "Datos actualizados correctamente" | Se descargó información nueva. |
| "Base de Datos Local: Lista" | "Usando datos almacenados localmente" | No se descargó nada nuevo; usas lo que ya tenías. |
| "Sin conexión al servidor" | "Usando datos locales almacenados" (u otro mensaje) | No hay internet o el servidor no respondió. Mensajes posibles: "Tiempo de espera agotado", "Token expirado — inicia sesión para sincronizar", "Sin conexión — usando datos locales". |
| "Base de Datos Local" | "Verificando conexión..." | Estado inicial, un instante. |

**Pasos**

1. Escribe tu usuario y contraseña.
2. Toca "INICIAR SESIÓN".
3. Espera a entrar al Panel principal.

**Sin internet**

No puedes **iniciar** sesión sin internet. Si ya habías iniciado sesión antes, no necesitas hacerlo otra vez: la app abre directo.

**Mensajes posibles y qué hacer**

| Mensaje | Qué hacer |
|---|---|
| "Campo obligatorio" (bajo un campo) | Llena el campo vacío. |
| Credenciales incorrectas (el servidor indica el motivo; si no, dice "Credenciales incorrectas") | Revisa usuario y contraseña. Si no la recuerdas, contacta a soporte. |
| "Usuario desactivado. Contacta a soporte." | Tu cuenta está desactivada. Habla con tu supervisor. |
| "Error del servidor: (número)" | El servidor falló. Intenta en unos minutos; si sigue, avisa a soporte. |
| Otro texto técnico (por ejemplo, de conexión) | Normalmente es falta de internet. Verifica tu conexión y vuelve a intentar. |

---

### 4.2 Panel principal

**Para qué sirve:** es tu pantalla de inicio. Desde aquí llegas a todo. **Cómo se llega:** al iniciar sesión, o al tocar "Ir al inicio" / "Ir al Inicio" al terminar un reporte.

`[CAPTURA 05: Panel principal sin avisos, con encabezado (nombre, Tech ID, ONLINE/OFFLINE), botón "Escanear QR" y los seis botones]`

**Elementos**

| Elemento | Qué hace |
|---|---|
| Ícono de persona + tu nombre + "Tech ID: …" | Abre "Mi Perfil". "Tech ID" es tu código de técnico (formato T-xxxx). |
| Punto y texto **ONLINE** (verde) / **OFFLINE** (naranja) | Indica el resultado de la **última sincronización automática**: ONLINE si terminó bien, OFFLINE si falló o aún no termina. No mide la señal en tiempo real. |
| "Ultima sync: …" | En esta versión el texto puede aparecer en blanco. Para ver la hora real de la última sincronización usa "Mi Perfil" o el Centro de Sincronización. |
| Banner naranja "Tienes N reportes pendientes de sincronizar" + **"Ir a Sincronizar"** | Aparece solo si hay algo pendiente de enviar. El número cuenta **todos los elementos** de la cola (reportes, fotos, firmas, PDFs, entregas), no solo reportes. |
| Banner azul "Grupo (cliente) en curso — N reporte(s) sin firmar" + **"Cerrar y firmar (N)"** | Aparece cuando dejaste reportes de un cliente "agrupados" para firmar todos juntos (sección 4.9). Un banner por cada cliente. |
| **"Escanear QR"** (botón azul grande) | Abre "Identificar Impresora". |
| **"Por Sync"** | Abre el Centro de Sincronización. |
| **"Clientes"** | Abre la lista de clientes. |
| **"Polizas"** | Abre la lista de pólizas. |
| **"Impresoras"** | Abre el inventario de impresoras. |
| **"Reportes"** | Abre la lista de reportes. |
| **"Alertas Riesgo"** | Aparece desactivado con la etiqueta "Próximamente"; no hace nada. |

`[CAPTURA 06: Panel principal con el banner naranja de pendientes y un banner azul de "Grupo … en curso"]`

**Sin internet:** el panel funciona igual. Verás **OFFLINE** y, si capturaste reportes, el banner de pendientes.

**Cada vez que abras la app o regreses a ella desde otra aplicación**, la app intenta sincronizar sola en segundo plano.

---

### 4.3 Mi Perfil

**Para qué sirve:** ver tus datos, guardar tu firma de técnico y cerrar sesión. **Cómo se llega:** Panel principal → tu nombre o el ícono de persona.

**Elementos**

| Elemento | Qué hace |
|---|---|
| Círculo con iniciales, nombre y correo | Tus datos de sesión. |
| "FIRMA DIGITAL DEL TÉCNICO" | Recuadro donde se muestra tu firma guardada. Texto de ayuda: *"Esta firma se adjuntará automáticamente como tu autorización en los reportes de servicio."* Si aún no tienes firma, el recuadro muestra un ícono de pluma y el texto "Firma Configurada" (el texto aparece aunque no hayas dibujado nada). |
| **"Actualizar Firma"** | Abre la hoja para dibujar tu firma. |
| "Versión de la App" | Versión y número de compilación de la app instalada en tu teléfono (por ejemplo, "0.1.0 (Build 1)"). Dícela a soporte si reportas un problema. |
| "Última Sincronización" | Fecha y hora de la última sincronización, o "Sin sincronización aún". |
| **"CERRAR SESIÓN"** | Cierra tu sesión **sin borrar tus datos**; si hay pendientes, antes pide confirmación (ver 2.3). |

**Pasos: guardar o actualizar tu firma de técnico**

1. Toca **"Actualizar Firma"**. Se abre una hoja "FIRMA DEL TÉCNICO" con el texto "Dibuja tu firma en el recuadro de abajo".
2. Dibuja tu firma con el dedo en el recuadro blanco.
3. Si te equivocas, toca **"Limpiar"** y dibuja de nuevo.
4. Toca **"Guardar Firma"** (se activa cuando ya dibujaste algo).
5. La firma aparece en el recuadro de "FIRMA DIGITAL DEL TÉCNICO".

`[CAPTURA 07: Hoja "FIRMA DEL TÉCNICO" con una firma dibujada y los botones "Limpiar" y "Guardar Firma"]`

`[CAPTURA 08: Mi Perfil con la firma ya guardada dentro del recuadro]`

**Sin internet:** todo funciona; tu firma se guarda en el teléfono. La firma se sube al servidor junto con tus reportes y entregas, y se usa en los PDF de entrega.

**Mensajes:** esta pantalla no muestra mensajes de error propios.

---

### 4.4 Identificar Impresora (escanear QR o buscar serial)

**Para qué sirve:** encontrar la impresora a la que le harás servicio. **Cómo se llega:** Panel principal → "Escanear QR".

**Elementos**

| Elemento | Qué hace |
|---|---|
| Visor de cámara con esquinas azules y la leyenda "Apunte la cámara al QR de la impresora" | Escanea el QR de la impresora. |
| "Procesando QR..." | La app leyó el código y busca la impresora. |
| **"Manual"** / **"Escanear"** (arriba a la derecha) | Apaga la cámara y deja solo la búsqueda manual / vuelve a encender la cámara. |
| "Cámara desactivada" + **"Activar escáner"** | Se muestra cuando apagaste la cámara. |
| "O buscar manualmente" | Divide la pantalla. |
| Campo "Ingrese número de serie..." + **"Buscar"** | Búsqueda manual por número de serie (acepta serial parcial). |
| "Búsquedas Recientes" | Hasta 5 impresoras de tus reportes más recientes. Toca una para abrirla. |
| "Coincidencias (N)" + **"Limpiar"** | Aparece si tu búsqueda tiene varios resultados. |
| Etiqueta **"EXACTO"** | Marca el resultado cuyo serial coincide exactamente con lo que escribiste. |
| Ícono de palomita verde en un resultado | La impresora tiene póliza activa. |
| **"Crear Nueva Impresora"** (botón inferior) | Abre "Nueva Impresora" (sección 4.17). |

`[CAPTURA 09: Identificar Impresora con la cámara activa y la leyenda "Apunte la cámara al QR de la impresora"]`

**Pasos: con QR**

1. Toca "Escanear QR" en el Panel principal.
2. Acepta el permiso de cámara si te lo pide.
3. Apunta la cámara al QR pegado en la impresora hasta que lea.
4. Si solo hay una impresora con ese serial, se abre **"Confirmar Equipo"** automáticamente. Si hay varias, aparece la lista "Coincidencias" y tocas la correcta.

**Pasos: sin QR**

1. Toca **"Manual"** (opcional, para apagar la cámara).
2. Escribe el número de serie en "Ingrese número de serie..." y toca **"Buscar"**.
3. Si hay un solo resultado, se abre "Confirmar Equipo". Si hay varios, toca el que tenga la etiqueta "EXACTO" o el que corresponda.

`[CAPTURA 10: Búsqueda manual con varios resultados: "Coincidencias (N)", un resultado con la etiqueta "EXACTO"]`

> El QR de las impresoras contiene el número de serie (formato `serie|modelo`). La app usa la parte del serial para buscar.

**Sin internet:** funciona completo; busca en las impresoras que ya están descargadas en tu teléfono. Si la impresora es nueva y aún no se ha descargado, usa **"Crear Nueva Impresora"**.

**Mensajes posibles**

| Mensaje | Qué hacer |
|---|---|
| "No se encontró ninguna impresora con ese serial." | Revisa el número. Si la impresora es nueva, toca "Crear Nueva Impresora". Si crees que debería existir, sincroniza (sección 6) y vuelve a buscar. |
| "Error al buscar: (detalle)" | Cierra y vuelve a abrir la pantalla. Si persiste, avisa a soporte. |
| La cámara no enciende | Ve a Ajustes de Android → Aplicaciones → Servicios - SMPC → Permisos → Cámara → Permitir, o usa la búsqueda manual (**"Manual"**). |

`[CAPTURA 11: Aviso "No se encontró ninguna impresora con ese serial." en la parte baja de la pantalla]`

---

### 4.5 Confirmar Equipo

**Para qué sirve:** verificar que es la impresora correcta antes de empezar. **Cómo se llega:** desde "Identificar Impresora".

**Elementos**

| Elemento | Qué hace |
|---|---|
| Etiqueta **"Poliza Activa"** (verde) o **"Sin Poliza"** | Indica si la impresora está cubierta por una póliza vigente. |
| Número de serie grande (los últimos 6 caracteres en azul) | Para comparar contra la etiqueta física. |
| Modelo y DPI (por ejemplo, "ZT411 - 203dpi") | Modelo de la impresora. |
| "Cliente" → "Planta" → "Area" | Dónde está la impresora. |
| Banner azul "Visita X/N en curso — el reporte quedará pendiente de entrega grupal" | La impresora pertenece a una póliza con visita en curso: el reporte **no pedirá firma individual**, se firmará en la entrega (sección 5.2). |
| Banner verde "Grupo (cliente) en curso — N reporte(s) sin firmar" + **"Firmar (N)"** | Hay reportes agrupados de ese cliente esperando firma (sección 4.9). Este banner **solo se muestra si la impresora pertenece a una póliza**; si no la tiene, abre el grupo desde el banner azul del Panel principal o desde Reportes → "Grupos abiertos". |
| **"Cancelar"** | Regresa sin hacer nada. |
| **"Ver detalle"** | Abre la Ficha Tecnica. |
| **"Crear reporte"** | Empieza el reporte de servicio. |

`[CAPTURA 12: Confirmar Equipo con etiqueta "Poliza Activa", serial, modelo y la ruta Cliente → Planta → Area]`

`[CAPTURA 13: Confirmar Equipo con el banner azul "Visita X/N en curso — el reporte quedará pendiente de entrega grupal"]`

**Pasos**

1. Compara el serial y el modelo con los que ves en la impresora.
2. Si es correcta, toca **"Crear reporte"**.
3. Si no es la correcta, toca **"Cancelar"** y busca de nuevo.

**Avisos que pueden aparecer al tocar "Crear reporte"**

| Aviso | Cuándo sale | Qué hacer |
|---|---|---|
| Diálogo **"Impresora asignada a otro técnico"**: *"Esta impresora está asignada al técnico (nombre) ((código)). ¿Deseas continuar de todas formas?"* | La impresora está asignada a otro técnico en una póliza con visita en curso. | **"Cancelar"** para no hacer el servicio, o **"Continuar"** si estás autorizado a atenderla. |
| Diálogo **"Reporte ya registrado"**: *"Esta impresora ya tiene un reporte registrado en la visita activa."* | Ya hiciste un reporte de esa impresora en la visita en curso y sigue pendiente de entrega. | **"Ver reporte existente"** para revisarlo, o **"Crear de todas formas"** solo si de verdad necesitas un segundo reporte. |

`[CAPTURA 14: Diálogo "Impresora asignada a otro técnico" con botones "Cancelar" y "Continuar"]`

`[CAPTURA 15: Diálogo "Reporte ya registrado" con botones "Ver reporte existente" y "Crear de todas formas"]`

> Estos avisos solo salen si entras por "Confirmar Equipo". Si abres "Crear reporte" desde otra pantalla (Impresoras, Detalle de Cliente, Ficha Tecnica), la app va directo a la captura sin preguntar. Para no saltarte avisos, prefiere entrar por "Escanear QR".

**Sin internet:** funciona completo.

---

### 4.6 Captura de Servicio

**Para qué sirve:** llenar el reporte. **Cómo se llega:** "Crear reporte".

**Elementos**

| Sección | Campo / botón | Detalle |
|---|---|---|
| Barra superior | **X** (arriba a la izquierda) y menú ⋮ → **"Cancelar Reporte"** | Ambos cancelan el reporte (piden confirmación). |
| "Información Básica" | **"Tipo de Servicio"** | Una opción: "Preventivo" (viene marcada), "Correctivo", "Diagnóstico", "Instalación". |
| | **"Contador de Pulgadas *"** (obligatorio), con ejemplo "Ejemplo: 125000" | Lee el contador de la impresora y escribe el número entero. |
| | **"Nivel de Darkness"** (opcional), con ejemplo "Ejemplo: 18.5" | Nivel de oscuridad. **Acepta decimales** (con punto o coma, por ejemplo 18.5). Se guarda tal cual y se muestra igual en el resumen, en "Ver Reporte" y en el PDF ("18.5"; si escribes un entero, como 18, se muestra "18"). |
| | **"Tipo de Etiqueta"** | "Papel TT" (viene marcada), "Papel TD" o "Plástica (BOPP/Poliéster)". |
| "Revision Tecnica" | Casillas | "Mantenimiento general", "Calibración sensores", "Rodillo dañado", "Cabezal dañado", "Sensor ribbon dañado", "Sensor papel dañado", "Pruebas", "Otros". Toca para marcar o desmarcar. |
| "Evidencia Fotografica" | **"Tomar Foto"** | Abre la cámara. |
| | **"Subir de Galería"** | Permite elegir varias fotos. |
| | Cuadrícula de fotos con **X** en cada una | Toca la X para quitar esa foto. Debajo aparece "N foto(s) adjunta(s)". |
| "Observaciones" | "Notas adicionales del técnico" | Texto libre, opcional. |
| Botón inferior | **"Revisar Reporte"** | Valida y pasa al resumen. |

`[CAPTURA 16: Captura de Servicio, parte superior: tipo de servicio, contador, darkness y tipo de etiqueta]`

`[CAPTURA 17: Captura de Servicio, parte inferior: casillas de "Revision Tecnica" y sección "Evidencia Fotografica" con 2 fotos]`

**Pasos**

1. Elige el **tipo de servicio**.
2. Escribe el **contador de pulgadas** (obligatorio).
3. Escribe el nivel de darkness si lo conoces.
4. Elige el **tipo de etiqueta**.
5. Marca todo lo que aplique en **"Revision Tecnica"** (al menos una).
6. Toma o sube **al menos 1 foto**.
7. Si quieres, escribe observaciones.
8. Toca **"Revisar Reporte"**.

> Las fotos se reducen automáticamente de tamaño (máximo 2048 px por lado y calidad reducida) para que se envíen más rápido.

**Cancelar el reporte**

1. Toca la **X** o el menú ⋮ → **"Cancelar Reporte"**.
2. Aparece el diálogo "Cancelar Reporte": *"Se perderán los cambios no guardados. Desea cancelar este reporte?"*
3. Toca **"Sí, cancelar"** para borrar lo capturado, o **"Seguir editando"** para continuar.

`[CAPTURA 18: Diálogo "Cancelar Reporte" con "Seguir editando" y "Sí, cancelar"]`

**Sin internet:** funciona completo. Es el uso normal en el sitio del cliente.

**Mensajes posibles** (aparecen en una franja roja abajo)

| Mensaje | Qué hacer |
|---|---|
| "Complete los campos obligatorios" | Escribe el contador de pulgadas. |
| "Ingrese un número válido" (bajo el contador o el darkness) | Escribe un número. El contador debe ser entero, sin letras ni puntos; el darkness sí puede llevar decimales (18.5). |
| "Debe seleccionar al menos una opción tecnica" | Marca al menos una casilla de "Revision Tecnica". |
| "Se requiere mínimo 1 foto de evidencia" | Agrega al menos una foto. |
| "No se pudo acceder a la cámara" | Revisa el permiso de cámara en Ajustes de Android, o usa "Subir de Galería". |

`[CAPTURA 19: Franja roja con el mensaje "Se requiere mínimo 1 foto de evidencia"]`

> Si sales de la captura con el botón "atrás" de Android (sin usar "Cancelar Reporte"), la app conserva en memoria el tipo de servicio, las casillas y las fotos del reporte anterior; los campos de texto (contador, darkness, observaciones) sí se limpian. Para empezar siempre en limpio, usa **"Cancelar Reporte"** cuando abandones un reporte.

---

### 4.7 Resumen del Reporte

**Para qué sirve:** revisar todo antes de pedir la firma. **Cómo se llega:** "Revisar Reporte".

**Elementos**

| Elemento | Detalle |
|---|---|
| "Estado: Por firmar" y etiqueta "Pendiente de Sync" | Fijos en esta pantalla: el reporte todavía no está guardado. |
| "1. Información del Equipo" | "Serial", "Modelo", "Tipo de Servicio", "Contador Actual", "Nivel de Darkness", "Etiqueta". Si no capturaste un valor, aparece "-". |
| "Evolución de Impresion (Contador)" | Gráfica de barras "Anterior" y "Actual", con "Servicio Anterior: … in \| Actual: … in". Si no hay servicio previo, el anterior es 0. Toca una barra para ver el incremento. |
| "Diagnóstico Técnico" | Lista de lo que marcaste (verde: mantenimiento, calibración, pruebas; amarillo: "Otros"; rojo: componentes dañados) y "Observaciones del Técnico" (si no escribiste nada: "Sin observaciones adicionales."). Si no marcaste nada: "Sin diagnósticos seleccionados." |
| "Evidencia Capturada" | Miniaturas de las fotos ("Sin fotos adjuntas" si no hay). Toca una para verla grande. |
| Botón inferior **"Proceder a Firma"** | Pasa a la firma del cliente. |
| Botón inferior **"Guardar reporte"** | Reemplaza al anterior cuando la impresora tiene una **visita de póliza en curso**: guarda el reporte sin pedir firma (sección 5.2). |

`[CAPTURA 20: Resumen del Reporte completo (equipo, gráfica de contador, diagnóstico y evidencia) con el botón "Proceder a Firma"]`

**Pasos**

1. Revisa los datos. Si algo está mal, regresa con la flecha y corrígelo.
2. Toca **"Proceder a Firma"** (o **"Guardar reporte"** si aplica).

**Sin internet:** funciona completo.

---

### 4.8 Firma de Conformidad (firma individual del cliente)

**Para qué sirve:** que el cliente firme y se guarde el reporte. **Cómo se llega:** "Proceder a Firma".

> Si la impresora tiene una visita de póliza en curso, esta pantalla **no pide firma**: muestra "Guardando reporte..." / "Guardando reporte de póliza..." y termina sola en "Servicio registrado". Ver sección 5.2.

**Elementos**

| Elemento | Detalle |
|---|---|
| "Firma del Cliente" | Recuadro gris para firmar con el dedo. Mientras está vacío dice "Dibuje la firma en el área de arriba". |
| **"Limpiar Firma"** | Borra la firma para dibujarla de nuevo. |
| "Datos del Firmante": **"Nombre completo de quien firma"** y **"Cargo / Puesto"** | Obligatorios. |
| "Envío por correo" | Solo aparece si el teléfono pudo consultar el servidor al abrir la pantalla. Dice "Se enviará a: (correos del cliente)" o "Sin correos registrados". |
| **"Agregar otro"** | Muestra el campo **"Correo adicional"** para sumar un correo. Si el cliente no tiene correos, el campo aparece directo. |
| **"Finalizar y Guardar Reporte"** | Guarda el reporte con la firma. |
| **"Agrupar con otros reportes de este cliente"** | Guarda el reporte **sin firma** para firmar varios reportes del mismo cliente en una sola firma (sección 4.9). |

`[CAPTURA 21: Firma de Conformidad con la firma dibujada, los datos del firmante y la tarjeta "Envío por correo"]`

`[CAPTURA 22: Parte inferior de la pantalla con los botones "Finalizar y Guardar Reporte" y "Agrupar con otros reportes de este cliente"]`

**Pasos: firma individual**

1. Entrega el teléfono al cliente (o a quien reciba el servicio).
2. Pide que dibuje su firma en el recuadro gris.
3. Escribe su **nombre completo** y su **cargo / puesto**.
4. Si aparece "Envío por correo", revisa a quién se enviará. Si falta algún correo, toca **"Agregar otro"** y escríbelo en **"Correo adicional"**.
5. Toca **"Finalizar y Guardar Reporte"**.
6. Aparece el diálogo **"Reporte Guardado"**: *"El reporte se guardó correctamente en la base local."* Toca **"Ir al Inicio"**.

`[CAPTURA 23: Diálogo "Reporte Guardado" con el botón "Ir al Inicio"]`

Al guardar, la app también genera el PDF del reporte y deja todo en cola para enviarse.

**Sin internet**

Funciona completo. La sección "Envío por correo" **no aparecerá** si no había conexión al abrir la pantalla (la app no puede consultar los correos del cliente), y por lo tanto tampoco el campo "Correo adicional". Los correos registrados del cliente se enviarán de todos modos cuando el reporte se sincronice (sección 6.4). Si necesitas mandar el reporte a otro correo, hazlo después con internet desde "Ver Reporte" → "Enviar" (sección 4.12).

**Mensajes posibles**

| Mensaje | Qué hacer |
|---|---|
| "Complete los campos obligatorios" | Llena nombre y cargo. Los campos marcan "Campo obligatorio". |
| "Se requiere la firma del cliente" | Haz que el cliente dibuje su firma. |
| "Correo inválido" (bajo "Correo adicional") | El correo adicional no tiene un formato válido y **el reporte no se guarda**. Escríbelo con el formato nombre@dominio.com o bórralo. |
| "Error al guardar: (detalle)" | Intenta de nuevo. Si persiste, avisa a soporte; no cierres la app antes de que termine. |
| "Error al agrupar: (detalle)" | Igual que el anterior. |

> La app revisa el formato del "Correo adicional" **antes de guardar**, tanto en "Finalizar y Guardar Reporte" como en "Agrupar con otros reportes de este cliente": si está mal escrito, muestra "Correo inválido" y no finaliza hasta que lo corrijas o lo borres.

---

### 4.9 Firma grupal (varios reportes del mismo cliente, una sola firma)

**Para qué sirve:** si haces servicio a varias impresoras del mismo cliente (que no están en una visita de póliza), el cliente puede firmar **una sola vez** al final. **Cómo se llega:**

- Panel principal → botón **"Cerrar y firmar (N)"** del banner azul.
- Reportes → pestaña **"Grupos abiertos"** → **"Cerrar y firmar (N reportes)"**.
- Confirmar Equipo → botón **"Firmar (N)"** del banner verde.

**Cómo se arma un grupo:** en cada reporte, en vez de "Finalizar y Guardar Reporte", toca **"Agrupar con otros reportes de este cliente"**. El reporte queda guardado **sin firma** y la app te lleva a "Servicio registrado". Todos los reportes agrupados del mismo cliente se juntan en un grupo abierto.

**Elementos de "Firma grupal — (cliente)"**

| Elemento | Detalle |
|---|---|
| "Reportes en este grupo (N)" | Lista de reportes del grupo con código, tipo de servicio y fecha. El ícono de ojo ("Ver reporte") abre cada uno. Si está vacío: "No hay reportes en este grupo." |
| "Firma del Cliente" + **"Limpiar"** | Firma única para todo el grupo. |
| "Datos del Firmante": **"Nombre completo"**, **"Cargo / Puesto"** | Obligatorios ("Requerido"). |
| "Envío por correo" | Igual que en 4.8. |
| **"Firmar grupo (N reporte(s))"** | Firma y cierra el grupo. |

`[CAPTURA 24: Firma grupal con la lista "Reportes en este grupo (N)", la firma dibujada y el botón "Firmar grupo (N reportes)"]`

**Pasos**

1. Abre la firma grupal por cualquiera de las rutas anteriores.
2. Revisa la lista de reportes (puedes abrir cada uno con el ojo).
3. Pide al cliente que firme en "Firma del Cliente".
4. Escribe nombre completo y cargo.
5. Toca **"Firmar grupo (N reporte(s))"**.
6. Aparece "Servicio registrado". Todos los reportes del grupo quedan firmados y listos para sincronizarse, con sus PDFs.

**Sin internet:** funciona; se envía al sincronizar.

**Mensajes:** "Se requiere la firma del cliente"; "Requerido" bajo nombre o cargo; "Correo inválido" si el "Correo adicional" está mal escrito (no se firma el grupo hasta corregirlo); "Error: (detalle)" si algo falla (reintenta).

---

### 4.10 Servicio registrado / Entrega registrada

**Para qué sirve:** confirmar que todo se guardó. **Cómo se llega:** al terminar de guardar un reporte (modo póliza o agrupado), una firma grupal o una entrega de póliza.

| Variante | Título | Subtítulo | Texto inferior |
|---|---|---|---|
| Reporte (póliza con visita en curso, o agrupado) | "Servicio registrado" | "Reporte guardado correctamente" | "El reporte se sincronizará con el servidor en el próximo ciclo de sync." |
| Firma grupal | "Servicio registrado" | "Reporte guardado correctamente" | Igual que arriba. |
| Entrega de póliza | "Entrega registrada" | "N equipo(s) firmado(s)" | "La entrega se sincronizará con el servidor en el próximo ciclo de sync." |

Botones: **"Ir al inicio"** (siempre) y **"Ver resumen de visita"** (solo en "Entrega registrada").

`[CAPTURA 25: Pantalla "Servicio registrado" con el botón "Ir al inicio"]`

`[CAPTURA 26: Pantalla "Entrega registrada" con "N equipos firmados" y los botones "Ver resumen de visita" e "Ir al inicio"]`

> Con el botón "atrás" de Android esta pantalla te lleva al Panel principal.

---

### 4.11 Reportes

**Para qué sirve:** consultar tus reportes. **Cómo se llega:** Panel principal → "Reportes". Tiene tres pestañas.

**Pestaña "Recientes"**

Muestra hasta **20 reportes** tuyos, **de cualquier estado**, del más nuevo al más viejo, con modelo, tipo de servicio, serial, cliente, fecha y una etiqueta con su estado: **"Firmado"**, **"Pendiente de entrega"** (reporte de póliza que espera la entrega), **"Pendiente de firma grupal"** (reporte agrupado sin firmar) o **"Sincronizado"**. Toca uno para abrir "Ver Reporte". Si no hay: "No hay reportes recientes".

> Para ver todos los reportes de una impresora usa "Historial de Servicios" (4.19); para los de un cliente, su "Detalle de Cliente".

`[CAPTURA 27: Reportes, pestaña "Recientes", con varias tarjetas de reporte]`

**Pestaña "Grupos abiertos"**

Una tarjeta por cliente con reportes agrupados sin firmar: nombre del cliente, "N reporte(s)", lista de equipos ("modelo · S/N: serie") y el botón **"Cerrar y firmar (N reportes)"** (abre la firma grupal, 4.9). Si no hay: "No hay grupos abiertos".

`[CAPTURA 28: Reportes, pestaña "Grupos abiertos", con una tarjeta de cliente y el botón "Cerrar y firmar"]`

**Pestaña "Póliza activa"**

Si tienes impresoras asignadas en una póliza con visita en curso, muestra: cliente, "Póliza (folio)", "N de M equipos atendidos", el botón **"Ver detalle de póliza"** (abre la lista de Pólizas) y la lista **"IMPRESORAS PENDIENTES"** con modelo, serial y "Planta / Área". Si no: "Sin visita de póliza activa".

`[CAPTURA 29: Reportes, pestaña "Póliza activa", con "N de M equipos atendidos" y la lista "IMPRESORAS PENDIENTES"]`

**Sin internet:** todo funciona con lo que ya está en tu teléfono.

---

### 4.12 Ver Reporte (detalle de un reporte)

**Para qué sirve:** ver un reporte completo, corregirlo, abrir su PDF y enviarlo por correo. **Cómo se llega:** tocando un reporte en cualquier lista, o "Ver Reporte" / "VER REPORTE" / "Ver reporte completo".

**Elementos**

| Elemento | Detalle |
|---|---|
| Título | El código del reporte (por ejemplo, R-0xx) o "Ver Reporte". |
| Etiquetas de tipo de servicio y de estado | Por ejemplo "PREVENTIVO", "CORRECTIVO", "DIAGNÓSTICO", "INSTALACIÓN"; y el estado ("SINCRONIZADO" o el estado interno, ver 7.3). |
| "INFORMACIÓN DEL REPORTE", "PARÁMETROS DEL SERVICIO" (contador y oscuridad), "DATOS DE LA IMPRESORA" (modelo, serie, cliente, código, técnico), "LISTA TÉCNICA", "NOTAS DEL SERVICIO", "EVIDENCIAS FOTOGRÁFICAS", "FIRMA DE CONFORMIDAD" (nombre y cargo; "No especificado" si no hay) | Datos del reporte. Toca una foto para verla en pantalla completa. |
| Lápiz (arriba a la derecha) — "Editar reporte" | Entra en modo edición. |
| **"Cerrar"** | Regresa. |
| **"PDF"** | Genera el PDF en el teléfono y abre la vista de impresión/compartir de Android. |
| **"Reimprimir"** | Solo en reportes firmados. Actualiza el reporte en el servidor y regenera el PDF. **Requiere internet.** |
| **"Enviar"** | Solo en reportes con estado "Signed". Envía por correo una **liga** para abrir el PDF (el correo ya no lleva el PDF adjunto; requiere internet). |

`[CAPTURA 30: Ver Reporte con los datos del servicio, evidencias y la barra inferior "Cerrar / PDF / Reimprimir / Enviar"]`

**Pasos: editar un reporte**

1. Toca el **lápiz** (arriba a la derecha). El título cambia a "Editando reporte".
2. Puedes cambiar: tipo de servicio, **"Contador de pulgadas lineales"**, **"Nivel de oscuridad (vacío si no aplica)"** y **"Notas / Observaciones"**.
3. Toca la **palomita verde** ("Guardar cambios") o la **X** ("Cancelar edición").
4. Mensajes: *"Reporte actualizado correctamente"* (se envió al servidor en ese momento) o *"Guardado localmente, se sincronizará después"* (no había conexión; se enviará en la próxima sincronización).

`[CAPTURA 31: Ver Reporte en modo edición ("Editando reporte") con los campos editables y los íconos de guardar y cancelar]`

**Pasos: enviar el reporte por correo**

1. Toca **"Enviar"** (solo aparece en reportes con estado "Signed").
2. Aparece el diálogo **"Enviar por correo"** con "Correos registrados:" y la lista de correos del cliente (o *"El cliente no tiene correos registrados."*).
3. Si quieres agregar otro, escríbelo en **"Correo adicional (opcional)"**.
4. Toca **"Enviar"** (o **"Cancelar"**).
5. Resultado: *"Email enviado"* o *"Error al enviar"*.

`[CAPTURA 32: Diálogo "Enviar por correo" con la lista "Correos registrados:" y el campo "Correo adicional (opcional)"]`

**Mensajes posibles**

| Mensaje | Qué hacer |
|---|---|
| "Reporte no encontrado" | El reporte ya no está en el teléfono. Regresa y vuelve a abrirlo; si persiste, sincroniza. |
| "Se requiere conexión para enviar email" | Conéctate a internet y vuelve a tocar "Enviar". |
| "Sin conexión, intenta cuando tengas internet" | Pasa con "Reimprimir" sin internet. Conéctate y reintenta. |
| "Error del servidor (número)" | Intenta más tarde; si sigue, avisa a soporte. |
| "Correo inválido" | Corrige el correo adicional. |
| "Error al generar PDF: (detalle)" | Intenta de nuevo; si persiste, avisa a soporte. |
| "Debe ser un número entero" (contador) / "Ingrese un número válido" (darkness) / "Requerido" (en edición) | Corrige el campo marcado. El darkness acepta decimales (18.5). |

**Visor de fotos:** al tocar una foto se abre a pantalla completa. Desliza de lado para cambiar de foto y pellizca para acercar.

`[CAPTURA 33: Visor de fotos a pantalla completa de una evidencia]`

---

### 4.13 Clientes

**Para qué sirve:** buscar clientes y ver sus impresoras, pólizas y reportes. **Cómo se llega:** Panel principal → "Clientes".

**Elementos**

| Elemento | Detalle |
|---|---|
| Etiqueta "Sincronizado" (arriba a la derecha) | Fija; no mide el estado real de sincronización. |
| Campo "Nombre, RFC o Contacto" | Busca mientras escribes. |
| Filtros: **"Todos"**, **"Con Poliza Activa"**, **"Sin Poliza"**, **"Con Riesgo"** | Filtran la lista. "Con Riesgo" muestra clientes con alguna póliza que vence en menos de 30 días. |
| Tarjeta de cliente | Estado (**"ESTABLE"**, **"RIESGO CRITICO"**, **"SIN POLIZA"**), "ID: #(número)", nombre, RFC ("Sin RFC" si no hay), contacto ("Sin contacto" si no hay), "N Zebra Units" y "N Polizas". El "ID: #" es solo un número de pantalla, no es un código oficial. |
| Botón **+** (flotante, "Nuevo Cliente") | Abre "Nuevo Cliente / Sitio". |
| Mensaje "No hay clientes para el filtro actual" | No hay coincidencias. |

`[CAPTURA 34: Lista de Clientes con filtros y varias tarjetas (ESTABLE, RIESGO CRITICO, SIN POLIZA)]`

**Pasos:** busca o filtra, y toca la tarjeta para abrir el "Detalle de Cliente".

**Sin internet:** funciona con los clientes ya descargados.

---

### 4.14 Nuevo Cliente / Sitio y Editar Cliente

**Para qué sirve:** dar de alta un cliente nuevo con sus plantas, o corregir sus datos. **Cómo se llega:** Clientes → botón **+**; o Detalle de Cliente → menú ⋮ → **"Editar Cliente"**.

**Campos**

| Sección | Campo | Obligatorio |
|---|---|---|
| "Datos del Corporativo" | "Nombre de la Empresa" | Sí |
| | "RFC" | No |
| | "Direccion Fiscal" | No |
| "Plantas / Sucursales" | "Nombre de la Planta" (viene como "Planta Matriz") | Sí |
| | "Nombre del Contacto" | Sí |
| | "Telefono del Contacto" | Sí |

Botón **"+ Agregar Planta"** agrega otra planta; el ícono **X** ("Quitar planta") la quita (la planta principal no se puede quitar).

`[CAPTURA 35: Pantalla "Nuevo Cliente / Sitio" con los datos del corporativo y una planta]`

**Pasos**

1. Llena los datos del corporativo.
2. Llena al menos una planta con contacto y teléfono.
3. Toca **"GUARDAR CLIENTE Y PLANTAS"** (al editar: **"ACTUALIZAR DATOS"**).
4. Aparece *"Cliente registrado correctamente"* (o *"Datos del cliente actualizados"*).

Cada planta nueva se crea con un área llamada "General".

**Sin internet:** funciona; se guarda en el teléfono. Los datos de un cliente nuevo viajan al servidor junto con el primer reporte de una de sus impresoras (sección 6).

**Mensajes:** "Revisa los campos obligatorios" y "Requerido" bajo cada campo vacío; "Error al guardar: (detalle)".

> **Precaución con "Eliminar Cliente":** en el ícono de bote de basura (modo edición) y en el menú ⋮ del Detalle de Cliente. Pregunta *"¿Estas seguro de eliminar este cliente y todos sus datos?"*. Desde el Detalle de Cliente el borrado **elimina de tu teléfono** el cliente, sus plantas, impresoras, pólizas, entregas y **reportes**. **No lo uses** salvo indicación expresa de tu supervisor.
>
> **Bloqueo por pendientes:** si el cliente tiene elementos pendientes de sincronizar (o con "Error"), la app **no deja eliminarlo** y muestra *"No se puede eliminar este cliente: tiene N elemento(s) pendiente(s) de sincronizar. Sincroniza primero y vuelve a intentarlo."* Sincroniza (sección 6) y vuelve a intentarlo.

---

### 4.15 Detalle de Cliente

**Para qué sirve:** ver todo de un cliente. **Cómo se llega:** Clientes → tocar un cliente.

**Elementos**

| Elemento | Detalle |
|---|---|
| Encabezado | Nombre, "RFC: …" ("Sin RFC"), dirección ("Ubicacion industrial no registrada" si falta) y contacto de la primera planta. La etiqueta "ONLINE" de arriba es fija. |
| Menú ⋮ | "Editar Cliente" y "Eliminar Cliente" (ver advertencia y bloqueo por pendientes en 4.14). |
| Pestaña **"Impresoras"** | "EQUIPOS REGISTRADOS (N)". Cada tarjeta: modelo, "S/N: …", etiqueta "ACTIVO" (fija), y botones **"Ver Detalles"** (Ficha Tecnica) y **"Reporte"** (empieza un reporte). Botón **"Nueva"** (alta de impresora). Vacío: "Sin impresoras registradas". |
| Pestaña **"Polizas"** | Folio, fechas, cobertura y estado. Toca una para abrir su detalle. Vacío: "No hay polizas registradas para este cliente". |
| Pestaña **"Reportes"** | Reportes de todas las impresoras del cliente: tipo, S/N, fecha y estado en mayúsculas (por ejemplo "SIGNED"). Toca uno para abrirlo. Vacío: "No hay reportes registrados para este cliente". |

`[CAPTURA 36: Detalle de Cliente, pestaña "Impresoras", con una tarjeta y los botones "Ver Detalles" y "Reporte"]`

`[CAPTURA 37: Detalle de Cliente, pestaña "Reportes", con reportes y su estado]`

**Sin internet:** funciona con los datos del teléfono.

---

### 4.16 Impresoras (inventario)

**Para qué sirve:** ver todas las impresoras activas y empezar un reporte directo. **Cómo se llega:** Panel principal → "Impresoras".

**Elementos**

| Elemento | Detalle |
|---|---|
| Campo "Buscar" | Busca por serial, modelo, cliente, planta o contacto. |
| Filtros: **"Todos"**, **"Por Cliente"**, **"Planta"**, **"Contacto"** | Al elegir uno (distinto de "Todos") aparece una segunda fila de opciones para escoger el cliente, planta o contacto. |
| "RESULTADOS (N)" | Cantidad de impresoras mostradas. |
| **"Agregar Impresora"** | Abre "Nueva Impresora". |
| Tarjeta de impresora | "NUMERO DE SERIE", etiqueta **"EN POLIZA"** o **"SIN POLIZA"**, "MODELO / DPI", "CLIENTE", planta y área, y botones **"Crear reporte"** y **"Ver detalle"**. |

`[CAPTURA 38: Inventario de Impresoras con búsqueda, filtros y tarjetas con "EN POLIZA" / "SIN POLIZA"]`

> "Crear reporte" desde aquí va directo a la captura, sin los avisos de "Confirmar Equipo" (ver 4.5).

**Sin internet:** funciona con las impresoras descargadas.

---

### 4.17 Nueva Impresora

**Para qué sirve:** dar de alta una impresora que no está en la lista y empezar su reporte. **Cómo se llega:** Identificar Impresora → "Crear Nueva Impresora"; Impresoras → "Agregar Impresora"; Detalle de Cliente → "Nueva".

**Campos ("Alta Rapida de Impresora")**

| Campo | Detalle |
|---|---|
| "Numero de Serie" | Obligatorio (ejemplo: 710232000196). |
| "Modelo y DPI" | Obligatorio; escribe o elige una sugerencia ("ZT411 - 203dpi", "ZT610 - 600dpi", "ZD421 - 203dpi", "105SL Plus"). Si no escribes DPI, se asume 203. |
| "Cliente" | Obligatorio; lista de clientes activos. |
| "Planta" | Obligatorio; se llena según el cliente. |
| "Área" | Obligatorio; escribe o selecciona ("Escribe o selecciona un área"). Si escribes una nueva, se crea. |

`[CAPTURA 39: Pantalla "Nueva Impresora" con serie, modelo, cliente, planta y área llenos]`

**Pasos**

1. Llena todos los campos.
2. Toca **"Guardar y Crear Reporte"**.
3. Aparece *"Impresora guardada localmente"* y se abre la captura del reporte para esa impresora.

Las impresoras creadas en la app reciben un código que empieza con **IA-** (por ejemplo, IA-001).

**Mensajes**

| Mensaje | Qué hacer |
|---|---|
| "Complete los campos obligatorios" / "Campo obligatorio" | Llena todo. |
| "El numero de serie ya existe en la base local" | Esa impresora ya está en tu teléfono: búscala por serial en vez de crearla. |
| "No se pudo guardar la impresora localmente" | Intenta de nuevo; si persiste, avisa a soporte. |

**Sin internet:** funciona; la impresora nueva viaja al servidor junto con su primer reporte.

---

### 4.18 Ficha Tecnica (detalle de impresora)

**Para qué sirve:** ver los datos de una impresora, su último servicio y su QR. **Cómo se llega:** "Ver detalle" desde Confirmar Equipo, Impresoras o "Ver Detalles" en Detalle de Cliente.

**Elementos**

| Elemento | Detalle |
|---|---|
| Etiqueta "OFFLINE READY" | Fija: la ficha se consulta sin internet. |
| Modelo, "S/N: …", "Código: …" (código I-xxxx, IA-xxx o parte del ID) y "CONTADOR ACTUAL" | Contador del último servicio ("N/A" si no hay). |
| "ESTADO DE LA IMPRESORA" | **"Correcta"** / "EN LINEA" (último reporte sin componentes dañados), **"Atencion"** / "ATENCION" (el último reporte tiene marcado rodillo, cabezal, sensor ribbon o sensor papel dañado) o **"Sin historial"** / "SIN HISTORIAL" (no hay reportes). |
| "DATOS DEL CLIENTE" | Cliente, planta y área. |
| "ULTIMO SERVICIO" | Tipo, fecha, contador, nombre del técnico y botón **"VER REPORTE"**. Si no hay reportes, el botón avisa *"Esta impresora no tiene reportes aún"*. |
| **"Crear reporte de servicio"** | Empieza un reporte. |
| **"Mostrar QR"** | Muestra el QR de la impresora en pantalla (diálogo "Código QR de Impresora", con "FORMATO DEL QR" y botón "Cerrar"). |
| **"Ver Historial"** | Abre "Historial de Servicios". |

`[CAPTURA 40: Ficha Tecnica con estado "Correcta"/"Atencion", datos del cliente y último servicio]`

`[CAPTURA 41: Diálogo "Código QR de Impresora" con el QR y el "FORMATO DEL QR"]`

---

### 4.19 Historial de Servicios

**Para qué sirve:** ver todos los servicios de una impresora. **Cómo se llega:** Ficha Tecnica → "Ver Historial".

**Elementos**

| Elemento | Detalle |
|---|---|
| Encabezado | Modelo, "S/N: …", "ID: …", "Total: N servicio(s)" y "Filtro: Todos" (o el tipo elegido). |
| Línea de tiempo | Cada servicio: fecha, código del reporte, técnico, notas (o "Sin notas"), "Contador: N in" y **"Ver Reporte"**. |
| Ícono de filtro (arriba a la derecha) | Abre la hoja "Filtrar por tipo de servicio" con las opciones "Todos", "Preventivo", "Correctivo", "Diagnóstico", "Instalación", y el orden "Más reciente primero" / "Más antiguo primero". Toca **"Aplicar"**. |
| Vacío | "No hay servicios para este filtro". |

`[CAPTURA 42: Historial de Servicios con la línea de tiempo de reportes]`

`[CAPTURA 43: Hoja "Filtrar por tipo de servicio" con las opciones de tipo y orden y el botón "Aplicar"]`

**Sin internet:** funciona.

---

### 4.20 Pólizas

**Para qué sirve:** ver pólizas y empezar la entrega de equipos atendidos. **Cómo se llega:** Panel principal → "Polizas".

**Elementos**

| Elemento | Detalle |
|---|---|
| Etiqueta "Sincronizado" | Fija; no mide el estado real. |
| Campo "Cliente o Folio" | Busca por cliente o folio. |
| Filtros: **"Todas"**, **"Vigentes"**, **"Por Vencer"**, **"Vencidas"** | "Por Vencer" son pólizas que vencen en menos de 30 días. |
| Banner azul "Pendientes de entrega — N reporte(s)" | Lista cada póliza con reportes por entregar: "(folio) — N equipo(s)" y botón **"Iniciar entrega"**. Aparece solo si hay pendientes. |
| Tarjeta de póliza | Folio, estado (**"VIGENTE"**, **"POR VENCER"**, **"VENCIDA"**), cliente, fechas y "N Equipos amparados". Si hay reportes por entregar, botón **"VER RESUMEN (N reportes)"**. Tocar la tarjeta abre el detalle. |
| Vacío | "No hay pólizas para el filtro actual". |

`[CAPTURA 44: Lista de Pólizas con el banner "Pendientes de entrega" y tarjetas VIGENTE / POR VENCER]`

> Las pólizas no se crean ni se editan desde la app: las da de alta la oficina y llegan a tu teléfono al sincronizar.

**Sin internet:** funciona con las pólizas descargadas.

---

### 4.21 Detalle de Póliza

**Para qué sirve:** ver qué equipos te tocan, cuáles ya atendiste y cómo van las visitas. **Cómo se llega:** Pólizas → tocar una póliza, o Detalle de Cliente → "Polizas".

**Elementos**

| Elemento | Detalle |
|---|---|
| Encabezado | Folio, estado (VIGENTE / POR VENCER / VENCIDA), cliente y fechas de vigencia. |
| Pestaña **"Mis Tareas (N)"** | Equipos que **tienes asignados**. Separa **"Por atender (N)"** y **"Atendidos (N)"** cuando hay de ambos. Etiquetas: **"TU ASIGNACIÓN"** (por atender) o **"COMPLETADO"** (ya tiene reporte en esta visita). |
| Pestaña **"Parque Total (N)"** | Todos los equipos de la póliza. Arriba: "N atendidos · N pendientes". Cada equipo: modelo, "S/N", "Planta / Área", y quién lo tiene asignado: **"Tú"**, el nombre de otro técnico o **"Sin asignar"**; los atendidos llevan **"ATENDIDO"**. |
| Pestaña **"Visitas (N)"** | Ver abajo. |
| Botón inferior **"VER RESUMEN (N reportes)"** | Aparece si hay reportes pendientes de entrega; abre la entrega (sección 4.22). |

Las asignaciones y la activación de visitas **las hace la oficina**; llegan a tu teléfono al sincronizar.

**Pestaña "Visitas"**

- Si no hay: "No hay visitas generadas para esta póliza".
- **Visita activa** (recuadro azul): "Visita X/N — En Curso" con una barra y "N/M equipos entregados": **N** es el número de equipos de la póliza cuyo reporte ya fue **entregado y firmado** en esta visita, y **M** el total de equipos de la póliza. Un reporte que sigue "pendiente de entrega" **todavía no cuenta**. La visita pasa a "COMPLETADA" cuando N llega a M (ver 5.2).
- **"Historial de visitas"**: "Visita X/N", fecha programada y estado: **"PROGRAMADA"**, **"EN CURSO"** o **"COMPLETADA"**. Si la oficina cerró la visita a mano, debajo aparece en cursiva **"Cerrada por la oficina (nombre): motivo"** con el motivo que escribió.
- **"Historial de entregas"** (si hay): fecha, "Firmó: (nombre)", etiqueta **"PARCIAL"** (si la entrega cubrió menos equipos que los de la póliza) y botón **"Ver resumen"** (4.24).

> **La app no tiene botones para iniciar ni para cerrar una visita.** Una visita pasa a "EN CURSO" cuando la oficina la activa desde el panel administrador y tú sincronizas. Lo mismo al terminar: la visita se completa sola cuando todos los equipos quedaron entregados (ver 5.2) o la **oficina puede cerrarla con el botón "Cerrar visita"**, indicando un motivo. En ambos casos aparece como **"COMPLETADA"** cuando sincronizas, y deja de tratarse como visita en curso: tus reportes de esa póliza ya no quedan "pendientes de entrega" y el banner "Visita X/N en curso" desaparece. Si no ves el cambio, sincroniza (sección 6).

`[CAPTURA 45: Detalle de Póliza, pestaña "Mis Tareas", con tarjetas "TU ASIGNACIÓN" y "COMPLETADO"]`

`[CAPTURA 46: Detalle de Póliza, pestaña "Parque Total", con "N atendidos · N pendientes" y etiquetas "Tú" / "Sin asignar" / "ATENDIDO"]`

`[CAPTURA 47: Detalle de Póliza, pestaña "Visitas", con la visita activa "Visita X/N — En Curso", el historial de visitas (incluida una COMPLETADA con "Cerrada por la oficina…") y el historial de entregas con "PARCIAL"]`

**Sin internet:** funciona con lo descargado.

---

### 4.22 Entrega de póliza (carrusel de equipos)

**Para qué sirve:** revisar los equipos que atendiste en la visita y pedir **una sola firma** al cliente. **Cómo se llega:** Pólizas → "Iniciar entrega" o "VER RESUMEN (N reportes)"; o Detalle de Póliza → "VER RESUMEN".

**Elementos**

| Elemento | Detalle |
|---|---|
| Título | El folio de la póliza, y arriba a la derecha "N/M equipos". |
| Puntos de página | Indican en qué equipo estás. Desliza de lado para ver el siguiente. |
| Tarjeta de equipo | Modelo, serie, "Planta / Área", tipo de servicio y fecha, "N elemento(s) en checklist", foto de evidencia y botón **"Ver reporte completo"**. |
| Botón inferior verde **"FIRMAR ENTREGA (N equipo(s))"** | Aparece cuando la entrega cubre **todos** los equipos que faltan de la visita. |
| Botón inferior ámbar **"FIRMAR ENTREGA PARCIAL (N de M equipos)"** | Aparece cuando atendiste **menos** equipos de los que faltan. |

`[CAPTURA 48: Entrega de póliza con el carrusel: tarjeta del equipo, puntos de página y "Ver reporte completo"]`

`[CAPTURA 49: Botón inferior de la entrega en sus dos versiones: verde "FIRMAR ENTREGA (N equipos)" y ámbar "FIRMAR ENTREGA PARCIAL (N de M equipos)"]`

**Pasos**

1. Desliza por todos los equipos y revisa. Abre "Ver reporte completo" si necesitas corregir algo.
2. Toca **"FIRMAR ENTREGA…"**.

**Sin internet:** funciona completo.

---

### 4.23 Firma de entrega

**Para qué sirve:** capturar la firma del cliente para todos los equipos de la entrega y, si hace falta, indicar un correo adicional al que también se enviará. **Cómo se llega:** botón "FIRMAR ENTREGA…".

**Elementos**

| Elemento | Detalle |
|---|---|
| "Firma del Cliente" | Recuadro con "Dibuje la firma en el área de arriba" y botón **"Limpiar"**. |
| "Datos del Firmante" | **"Nombre completo"** y **"Cargo / Puesto"**. |
| "Envío por correo" | Solo aparece si el teléfono pudo consultar el servidor al abrir la pantalla. Dice **"Se enviará a: (correos del cliente)"** o **"Sin correos registrados"**. |
| **"Agregar otro"** | Muestra el campo **"Correo adicional"** para sumar un correo. Si el cliente no tiene correos, el campo aparece directo. |
| **"Confirmar Entrega"** | Guarda la entrega. |

`[CAPTURA 50: Firma de entrega ("Firma — folio") con la firma dibujada, nombre y cargo, y el botón "Confirmar Entrega"]` · **REPETIR** (la pantalla cambió: ahora tiene la tarjeta "Envío por correo")

`[CAPTURA 59: Firma de entrega con la tarjeta "Envío por correo" ("Se enviará a: …") y el campo "Correo adicional" visibles]`

**Pasos**

1. Entrega el teléfono al cliente para que firme.
2. Escribe nombre completo y cargo.
3. Si aparece "Envío por correo", revisa a quién se enviará. Si falta algún correo, toca **"Agregar otro"** y escríbelo en **"Correo adicional"** (por ejemplo, el de quien firma). Es opcional.
4. Toca **"Confirmar Entrega"**.
5. Aparece **"Entrega registrada"** (4.10). Los reportes quedan en estado firmado, se generan los PDFs de cada reporte y todo se encola para sincronizar.

**Mensajes**

| Mensaje | Qué hacer |
|---|---|
| "Se requiere la firma del cliente" | Pide al cliente que firme. |
| "Requerido" (bajo nombre o cargo) | Completa el campo. |
| "Correo inválido" (bajo "Correo adicional") | El correo adicional no tiene un formato válido (nombre@dominio.com) y **la entrega no se guarda**. Corrígelo o bórralo. |
| "Error: (detalle)" | Reintenta. |

> La app revisa el formato del "Correo adicional" **antes de guardar**: si está mal escrito muestra "Correo inválido" y no confirma la entrega hasta que lo corrijas o lo borres. Si no escribes ningún correo adicional, todo funciona igual que antes.

**Sin internet:** la entrega se puede firmar y se guarda completa, pero la tarjeta **"Envío por correo" no aparece** (la app no puede consultar los correos del cliente) y, por lo tanto, **tampoco el campo "Correo adicional"**: no se puede escribir un correo adicional sin conexión. Es el mismo comportamiento de las firmas individual (4.8) y grupal (4.9). El correo de la entrega se enviará de todos modos a los correos registrados del cliente cuando sincronices (sección 6.4). El PDF de resumen de la entrega lo genera el servidor al sincronizar.

---

### 4.24 Resumen de visita

**Para qué sirve:** consultar una entrega ya firmada. **Cómo se llega:** "Ver resumen de visita" (en "Entrega registrada") o "Ver resumen" (Detalle de Póliza → Visitas).

**Elementos**

| Elemento | Detalle |
|---|---|
| Encabezado | Folio, etiqueta "ENTREGADA", "Fecha de entrega" y "Firmó". |
| Avance | "N de M equipos atendidos". |
| "Equipos en esta entrega" | Por cada equipo: modelo, "S/N", tipo de servicio, etiqueta "Firmado" o "Pendiente", aviso "Con advertencias" si hay componentes dañados u "Otros", y botones **"Ver PDF"** y **"Ver reporte"**. |
| **"Ver / Compartir PDF de resumen"** | Genera en el teléfono el PDF de la entrega y abre la vista de imprimir/compartir. |

`[CAPTURA 51: Resumen de visita con "N de M equipos atendidos", lista de equipos y el botón "Ver / Compartir PDF de resumen"]`

**Mensajes:** "No se encontró la entrega", "Error al generar PDF", "Datos no disponibles", "Reporte no encontrado".

> El PDF de resumen de la entrega que se guarda en el servidor lo genera el propio servidor al sincronizar; no necesitas subirlo tú.

---

### 4.25 Centro de Sincronización

**Para qué sirve:** ver qué falta por enviar y sincronizar. **Cómo se llega:** Panel principal → "Por Sync" o "Ir a Sincronizar".

**Elementos**

| Elemento | Detalle |
|---|---|
| Tarjeta superior | "Conectado al Servidor Local" (texto fijo) o "Sincronizando..." y, abajo, "Última sync: (fecha y hora)" o "Sin sincronización aún". Durante la sincronización muestra el avance. |
| Resumen | "N reporte(s) · N archivo(s) · N entrega(s)" (o "Sin elementos pendientes") y "N total". |
| "PENDIENTES DE SUBIR" | Listas: **"Reportes de Servicio"**, **"Archivos y Firmas"** (fotos, firmas y PDFs) y **"Entregas de Póliza"**. Cada fila: código o nombre, detalle y una etiqueta **"Pendiente"** (naranja) o **"Error"** (rojo, con el motivo en rojo debajo). |
| **"INICIAR SINCRONIZACIÓN MASIVA"** | Descarga novedades y sube lo pendiente. Durante el proceso dice "Sincronizando...". |
| **"Reintentar N fallido(s)"** | Solo aparece si hay elementos en "Error". |
| Ícono de reloj (arriba a la derecha) | Abre el "Historial de Sincronización" (ver más abajo). |
| Vacío | "Todo sincronizado — No hay elementos pendientes de subir al servidor". |

`[CAPTURA 52: Centro de Sincronización con elementos "Pendiente", el resumen de conteos y el botón "INICIAR SINCRONIZACIÓN MASIVA"]`

`[CAPTURA 53: Centro de Sincronización con elementos en "Error" (mensaje rojo) y el botón "Reintentar N fallidos"]`

**Pasos**

1. Conéctate a internet (datos móviles o Wi-Fi).
2. Entra al Centro de Sincronización.
3. Toca **"INICIAR SINCRONIZACIÓN MASIVA"** y espera.
4. Revisa el aviso final.
5. Si quedaron elementos en "Error", toca **"Reintentar N fallido(s)"**.

**Avisos posibles al terminar** (barra de color en la parte baja)

| Aviso | Significado y qué hacer |
|---|---|
| "No hay elementos pendientes para sincronizar" | No había nada que enviar. |
| "Completado: N enviado(s)" | Todo se envió. |
| "Sin conexión — los pendientes se conservan y se enviarán cuando haya internet" | No había internet. No se perdió nada ni se contó como intento fallido; vuelve a sincronizar con conexión. |
| "N OK · M fallido(s) (reintento automático)" | Se envió una parte; el resto se reintenta. Vuelve a sincronizar con mejor señal. |
| "Sesión expirada — inicia sesión para sincronizar. Puedes seguir usando la app sin conexión." | Pasó más de un año desde tu última sincronización. Cierra sesión e inicia otra vez (sección 8). |
| (La app te lleva a la pantalla de inicio de sesión) | El administrador desactivó tu usuario o revocó tu sesión. Tus datos y pendientes siguen en el teléfono; inicia sesión de nuevo (o consulta a tu supervisor). |
| Aviso adicional "N pendiente(s) de otro técnico" | Hay pendientes en este teléfono que pertenecen a otro técnico; no se envían con tu sesión (ver 2.3). |
| "Error de red: (detalle)" | No hay conexión. Verifica tu internet y reintenta. |

Mensajes de avance mientras sincroniza: "Conectando al servidor…", "Descargando datos del servidor...", "Sin conexión — usando datos locales", "Reintentando fallidos…".

`[CAPTURA 54: Aviso de resultado tras sincronizar ("Completado: N enviados" y, en otra captura, "Sesión expirada…")]`

`[CAPTURA 55: Centro de Sincronización vacío: "Todo sincronizado"]`

**Historial de Sincronización**

**Para qué sirve:** comprobar qué reportes ya llegaron al servidor y cuáles están en error. **Cómo se llega:** Centro de Sincronización → ícono de reloj.

| Elemento | Detalle |
|---|---|
| "En error (N)" | Aparece solo si hay elementos que el servidor rechazó 3 veces. Cada tarjeta indica el elemento (por ejemplo, "Reporte R-012"), el equipo y cliente, el número de intentos y el **motivo** del error en rojo. |
| "Subidos recientemente (últimos 50)" | Los últimos 50 reportes confirmados por el servidor, del más reciente al más antiguo. Cada tarjeta muestra el **código del reporte (R-xxx)**, el **serial de la impresora**, el **cliente** y la **fecha y hora** en que se sincronizó. |
| Vacío | "Aún no hay reportes sincronizados". |

Jala la lista hacia abajo para actualizarla. Para reintentar un elemento en error usa **"Reintentar N fallido(s)"** en el Centro de Sincronización.

`[CAPTURA 56: Historial de Sincronización con la sección "Subidos recientemente" (código R-xxx, serial, cliente y fecha/hora)]`

`[CAPTURA 57: Historial de Sincronización con la sección "En error" y el motivo en rojo]`

---

## 5. Flujos completos de principio a fin

### 5.1 Servicio a una impresora (con firma individual del cliente)

Tiempo aproximado: unos minutos. Funciona sin internet.

1. **Abre la app.** Si no iniciaste sesión antes, hazlo (necesitas internet; sección 2.2). Llegas al Panel principal (`CAPTURA 05`).
2. Toca **"Escanear QR"**. Acepta el permiso de cámara si lo pide.
3. **Escanea el QR** pegado a la impresora (`CAPTURA 09`). Si no tiene QR o no lee, toca **"Manual"**, escribe el serial y toca **"Buscar"** (`CAPTURA 10`).
4. En **"Confirmar Equipo"** compara serial y modelo (`CAPTURA 12`). Toca **"Crear reporte"**.
   - Si sale "Impresora asignada a otro técnico" o "Reporte ya registrado", lee la sección 4.5 antes de continuar.
5. En **"Captura de Servicio"** (`CAPTURA 16`, `CAPTURA 17`):
   1. Elige el **tipo de servicio**.
   2. Escribe el **contador de pulgadas**.
   3. (Opcional) escribe el nivel de darkness (admite decimales, por ejemplo 18.5) y elige el **tipo de etiqueta**.
   4. Marca la **revisión técnica** (al menos una casilla).
   5. Toma las **fotos** con **"Tomar Foto"** o elige de **"Subir de Galería"** (mínimo 1).
   6. Escribe **observaciones** si hace falta.
   7. Toca **"Revisar Reporte"**.
6. En **"Resumen del Reporte"** revisa todo (`CAPTURA 20`). Toca **"Proceder a Firma"**.
7. En **"Firma de Conformidad"** (`CAPTURA 21`):
   1. Que el cliente **firme** en el recuadro.
   2. Escribe su **nombre completo** y **cargo / puesto**.
   3. Si aparece "Envío por correo", confirma los destinatarios o agrega uno en "Correo adicional".
8. Toca **"Finalizar y Guardar Reporte"**. Aparece **"Reporte Guardado"** (`CAPTURA 23`). Toca **"Ir al Inicio"**.
   - En este momento la app guardó el reporte, **generó el PDF** y dejó todo en la cola para sincronizar.
9. **Sincroniza** cuando tengas internet:
   1. En el Panel principal verás el banner "Tienes N reportes pendientes de sincronizar" (`CAPTURA 06`). Toca **"Ir a Sincronizar"** (o el botón "Por Sync").
   2. Toca **"INICIAR SINCRONIZACIÓN MASIVA"** (`CAPTURA 52`).
   3. Espera el aviso "Completado: N enviado(s)" (`CAPTURA 54`).
10. **Verifica:** en "Por Sync" debe aparecer "Todo sincronizado" (`CAPTURA 55`).
11. Para ver o compartir el PDF: **Reportes** → toca el reporte → **"PDF"** (`CAPTURA 30`).

**Variante: varias impresoras del mismo cliente con una sola firma**
En el paso 7, en vez de firmar, toca **"Agrupar con otros reportes de este cliente"** (`CAPTURA 22`). Repite los pasos 2 a 6 con cada impresora y agrupa cada una. Al terminar, en el Panel principal toca **"Cerrar y firmar (N)"** (`CAPTURA 06`), pide la firma una sola vez en la **Firma grupal** (`CAPTURA 24`) y toca **"Firmar grupo"**.

### 5.2 Entregas de póliza y entregas parciales

**Cómo funciona (resumen):**

- Una póliza tiene varias **visitas** ("Visita 1/4", "Visita 2/4", etc.). La oficina **activa** una visita; cuando la sincronizas, aparece como **"EN CURSO"** (`CAPTURA 47`).
- Mientras haya una visita en curso, los reportes de las impresoras de esa póliza **no piden firma individual**: quedan **"pendientes de entrega"**.
- Al terminar de atender los equipos, haces **una sola entrega**: el cliente firma una vez por todos los equipos atendidos.

**Pasos**

1. **Sincroniza** al llegar (sección 6) para recibir tu asignación y la visita activa.
2. Abre **Polizas** → toca la póliza → revisa **"Mis Tareas"** (`CAPTURA 45`) y **"Visitas"** (`CAPTURA 47`). Debe verse "Visita X/N — En Curso".
3. Atiende cada equipo de **"Mis Tareas"** como en el flujo 5.1:
   - En "Confirmar Equipo" verás el banner azul "Visita X/N en curso — el reporte quedará pendiente de entrega grupal" (`CAPTURA 13`).
   - En el resumen, el botón dice **"Guardar reporte"** (no "Proceder a Firma"). Tócalo.
   - La app guarda el reporte sin pedir firma y muestra **"Servicio registrado"** (`CAPTURA 25`).
4. Repite con cada equipo. En "Mis Tareas" cada equipo atendido pasa a **"COMPLETADO"**.
5. Cuando termines, ve a **Polizas**. Verás el banner **"Pendientes de entrega — N reporte(s)"** (`CAPTURA 44`). Toca **"Iniciar entrega"** (o **"VER RESUMEN (N reportes)"**).
6. En el carrusel **revisa cada equipo** (`CAPTURA 48`).
7. Mira el botón inferior (`CAPTURA 49`):
   - **Verde "FIRMAR ENTREGA (N equipos)"**: la entrega cubre todos los equipos que faltan.
   - **Ámbar "FIRMAR ENTREGA PARCIAL (N de M equipos)"**: atendiste solo una parte; es una **entrega parcial**.
8. Toca el botón. En **"Firma de entrega"** (`CAPTURA 50`) el cliente firma, escribes nombre y cargo y tocas **"Confirmar Entrega"**.
9. Aparece **"Entrega registrada"** (`CAPTURA 26`). Puedes tocar **"Ver resumen de visita"** (`CAPTURA 51`).
10. **Sincroniza.** La entrega y los PDFs se envían; el servidor genera el PDF de resumen de la entrega y, cuando ya tiene todos los PDFs, manda **un solo correo** al cliente con las ligas (sección 6.4).

**Entregas parciales**

- En una entrega parcial el historial de entregas muestra la etiqueta **"PARCIAL"** (`CAPTURA 47`).
- Los equipos que faltan se atienden **dentro de la misma visita** (sigue "EN CURSO") y se entregan después con otra firma.
- **Cuándo se cierra la visita:** la visita pasa a **"COMPLETADA" automáticamente cuando todos los equipos de la póliza tienen su reporte entregado y firmado** en esa visita. Mientras falte alguno, la visita sigue **"EN CURSO"**, aunque ya no queden reportes pendientes de entrega. Un reporte que solo está "pendiente de entrega" **no cuenta** como entregado.
- **Cierre manual por la oficina:** si hay equipos que no se pueden atender (el cliente no dio acceso, el equipo se retiró, etc.), la **oficina puede cerrar la visita** desde el panel administrador con el botón **"Cerrar visita"**. Antes de cerrar, el panel muestra cuántos equipos tienen reporte entregado y cuáles no, y **pide un motivo obligatorio**. No se puede cerrar mientras la póliza tenga reportes "pendientes de entrega": primero hay que entregarlos (con la firma del cliente). Al sincronizar, la visita aparece como **"COMPLETADA"** y, en el historial de visitas, muestra quién la cerró y el motivo. Después la oficina puede activar la siguiente visita. Una visita cerrada así **no se vuelve a abrir sola**, aunque llegue una entrega tardía.
- El contador de la visita activa ("N/M equipos entregados", en Detalle de Póliza → "Visitas") y el botón de firma siguen esta misma regla: el botón es **verde** ("FIRMAR ENTREGA") cuando esa firma deja entregados todos los equipos que faltaban —y por lo tanto cierra la visita— y **ámbar** ("FIRMAR ENTREGA PARCIAL") cuando todavía quedarían equipos por entregar.
- Para ver el avance de una visita usa **Detalle de Póliza → "Parque Total"** ("N atendidos · N pendientes"), **"Mis Tareas"** y el contador de la pestaña "Visitas".

**Si es una impresora de otro técnico:** la app avisa "Impresora asignada a otro técnico". Atiéndela solo si tienes autorización.

### 5.3 Firma del técnico en el perfil

Haz esto una vez (y cuando quieras actualizarla).

1. Panel principal → toca tu **nombre** o el **ícono de persona** → "Mi Perfil" (`CAPTURA 04`).
2. En "FIRMA DIGITAL DEL TÉCNICO" toca **"Actualizar Firma"**.
3. Dibuja tu firma (`CAPTURA 07`). Si te equivocas, **"Limpiar"**.
4. Toca **"Guardar Firma"**. Tu firma aparece en el recuadro (`CAPTURA 08`).
5. Tu firma se sube al servidor con tu siguiente sincronización y se usa en los PDF de entregas de póliza.

---

## 6. Trabajo sin conexión y sincronización

### 6.1 Qué puedes hacer sin internet

| Con internet | Sin internet |
|---|---|
| Iniciar sesión por primera vez | — (no se puede) |
| Sincronizar (enviar y recibir) | — (no se puede) |
| Reimprimir PDF, enviar un reporte por correo | — (no se puede) |
| Ver "Envío por correo" con los correos del cliente al firmar | La sección no aparece |
| Todo lo demás: escanear, capturar reportes, fotos, firmas, entregas, consultar clientes, impresoras, pólizas y reportes, editar un reporte | **Funciona igual** (editar un reporte se guarda en el teléfono y se envía después) |

### 6.2 Cuándo sincroniza la app

- **Automáticamente** al abrir la app y cada vez que regresas a ella desde otra aplicación (si tu sesión sigue vigente). Si en ese momento **no hay conexión**, la app no intenta sincronizar.
- **Manualmente** con "INICIAR SINCRONIZACIÓN MASIVA" en el Centro de Sincronización.
- En la pantalla de inicio de sesión, con **"Forzar Sync"** (solo descarga datos).

Cada sincronización hace dos cosas: **descarga** novedades (clientes, impresoras, pólizas, asignaciones, visitas, técnicos) y **sube** lo que está pendiente. Cuando termina con éxito, tu sesión se **renueva** por otro periodo completo.

### 6.3 Estados de la cola de sincronización

Cada elemento por enviar (reporte, foto, firma, PDF, entrega) entra en una cola. Se envían en este orden: **reportes → entregas de póliza → archivos (fotos, firmas, PDFs)**.

| Estado | Cómo se ve | Qué significa | Qué hacer |
|---|---|---|---|
| **Pendiente** | Etiqueta naranja "Pendiente" en el Centro de Sincronización; cuenta en el banner del Panel principal | Está guardado en tu teléfono y espera a enviarse. También se queda así si el servidor lo rechazó una o dos veces (la app lo reintenta sola en la siguiente sincronización) o si **no había internet** (eso nunca cuenta como fallo). | Sincroniza con internet. |
| **Sincronizado** | **Desaparece** de la lista de pendientes. Si ya no queda nada, aparece "Todo sincronizado". | Llegó al servidor. | Nada. |
| **Fallido** | Etiqueta roja **"Error"** con el motivo en rojo debajo; aparece el botón "Reintentar N fallido(s)" | El **servidor lo rechazó 3 veces** (errores reales del servidor). La falta de internet, un tiempo de espera agotado o un problema de red **no** llevan a "Error". | Toca **"Reintentar N fallido(s)"**. Si el motivo persiste, avisa a soporte. |

**Cómo reintentar:** Centro de Sincronización → **"Reintentar N fallido(s)"**. Pone los elementos con error otra vez en "Pendiente" con intentos en cero y los vuelve a enviar.

> **Sin internet no pasa nada:** si abres la app o sincronizas sin conexión, los elementos se quedan "Pendiente" tal cual, sin sumar intentos. Cuando haya internet se envían.
>
> **Si la sesión es revocada** (el administrador desactiva tu usuario) la app te pide iniciar sesión, pero **no borra** nada: al volver a entrar con tu usuario se retoma la cola pendiente.

**Estado de un reporte (distinto al de la cola):** ver sección 7.3. Cuando un reporte llega al servidor, **su estado en el teléfono no cambia** (un reporte firmado sigue "Signed"); la app anota la fecha y hora en que el servidor lo confirmó y las muestra en el **Historial de Sincronización** (sección 4.25). La etiqueta "Sincronizado"/"SYNCED" solo aparece en reportes que el teléfono recibió del servidor sin un estado propio.

### 6.4 Cuándo se envía el correo al cliente

**Los correos ya no llevan PDFs adjuntos.** En su lugar llevan una **liga** para abrir el PDF. Cada liga es personal (no se puede adivinar), **vence a los 30 días** (la oficina puede cambiar ese plazo) y no requiere iniciar sesión; si vence, o la oficina la regenera, deja de funcionar y la oficina puede enviar una nueva.

**Reportes sueltos o agrupados (fuera de póliza)**

- El correo con la **liga al PDF del reporte** se dispara **automáticamente en el momento en que el PDF del reporte llega al servidor** (es decir, durante una sincronización con internet).
- Los destinatarios son: los **correos registrados del cliente** (los administra la oficina) **más** el "Correo adicional" que hayas escrito al firmar (si lo escribiste bien), sin repetir direcciones.
- Si el cliente **no tiene correos** y no escribiste uno adicional, **no se envía correo**.
- Si el envío falla, la app **no te avisa** y no bloquea la sincronización. Puedes enviarlo a mano desde **Ver Reporte → "Enviar"** (con internet; solo reportes con estado "Signed"); ese correo también lleva la liga.

**Entregas de póliza: un solo correo por entrega**

- El cliente recibe **un solo correo por cada entrega** (no uno por cada reporte). Incluye: folio de la póliza, cliente, fecha, quién firmó, número de equipos entregados y una tabla con cada equipo (modelo, serie y tipo de servicio) con **su liga al PDF del reporte**, más la liga al **PDF de resumen de la entrega**.
- El correo sale **solo cuando el servidor ya tiene todo lo que va a ligar**: la firma, el PDF de resumen y el PDF de cada reporte de la entrega. Como la sincronización sube primero los reportes, luego la entrega y al final los archivos, **el correo sale cuando llega el último archivo**; si falta alguno, espera. Nunca se envía dos veces la misma entrega.
- Los destinatarios son los **correos registrados del cliente** más el **"Correo adicional" que escribiste al firmar la entrega** (4.23), sin repetir direcciones.
- La oficina puede **reenviar** el correo de una entrega desde el panel administrador y, si hace falta, **regenerar las ligas** (las anteriores dejan de funcionar).
- Si algún PDF de reporte nunca llega al servidor, la entrega queda sin correo automático; la oficina puede enviarlo a mano.

**Siempre**

- Los **correos de contacto** del cliente no se pueden cambiar desde la app.

### 6.5 Recomendaciones

1. Sincroniza **al llegar** al sitio (para recibir asignaciones y visitas) y **al terminar** el día.
2. Si cierras sesión con elementos pendientes, no se pierden, pero no se envían hasta que vuelvas a iniciar sesión con tu usuario y sincronices.
3. No desinstales la app con elementos pendientes.
4. Procura que tu teléfono tenga **fecha y hora automáticas**.

---

## 7. Códigos y glosario

### 7.1 Códigos legibles

| Código | Qué es | Ejemplo |
|---|---|---|
| **T-xxxx** | **Técnico.** Tu código de técnico; aparece como "Tech ID" en el Panel principal. | T-0001 |
| **I-xxxx** | **Impresora** dada de alta por la oficina. Aparece en la Ficha Tecnica como "Código". | I-0001 |
| **IA-xxx** | **Impresora creada desde la app** (con "Nueva Impresora"). | IA-001 |
| **R-xxx** | **Reporte** de servicio. Se genera en el teléfono al guardar el reporte, numerando los reportes que ya tiene tu teléfono. | R-001 |
| **P-xxx** | **Póliza** (código interno). | P-001 |
| **POL-AAAA-xxx** | **Folio de póliza**, el que ves en pantalla. | POL-2026-004 |

> El código R-xxx lo calcula cada teléfono, por lo que **puede repetirse entre técnicos y no afecta**, porque el sistema identifica el reporte internamente por UUID (un identificador único), no por su R-xxx.

El PDF de un reporte se nombra con las iniciales del técnico y el número: **R-(iniciales)-(número).pdf**. El PDF de una entrega usa el folio de la póliza.

### 7.2 Estados de equipo y póliza

| Término | Dónde aparece | Significado |
|---|---|---|
| "Correcta" / "EN LINEA" | Ficha Tecnica | El último reporte no marcó componentes dañados. |
| "Atencion" / "ATENCION" | Ficha Tecnica | El último reporte marcó rodillo, cabezal, sensor ribbon o sensor papel dañado. |
| "Sin historial" / "SIN HISTORIAL" | Ficha Tecnica | La impresora no tiene reportes. |
| "EN POLIZA" / "SIN POLIZA" | Impresoras | La impresora pertenece o no a una póliza. |
| "Poliza Activa" / "Sin Poliza" | Confirmar Equipo | La impresora tiene o no una póliza vigente. |
| "VIGENTE" | Pólizas | Póliza con más de 30 días para vencer. |
| "POR VENCER" | Pólizas | Vence en menos de 30 días. |
| "VENCIDA" | Pólizas | Ya pasó la fecha de término. |
| "ESTABLE" / "RIESGO CRITICO" / "SIN POLIZA" | Clientes | Cliente con póliza vigente / con póliza por vencer / sin póliza vigente. |

### 7.3 Estados de reporte (como los ves en pantalla)

| Estado (texto interno) | Qué significa |
|---|---|
| **Signed** | Reporte firmado por el cliente (firma individual o grupal). |
| **pending_delivery** | Reporte de una póliza con visita en curso: **espera la entrega** con firma. |
| **pending_group_signature** | Reporte **agrupado**: espera la firma grupal del cliente. |
| **signed** (minúsculas) | Reporte de póliza ya **entregado** y firmado en una entrega. |
| **Synced / SINCRONIZADO** | Estado que toma un reporte recibido del servidor sin estado propio. **No** es el aviso de que tu reporte ya se subió: para eso usa el Historial de Sincronización (4.25). |

### 7.4 Estados de visita y de entrega

| Término | Significado |
|---|---|
| "PROGRAMADA" | Visita planeada, aún no activa. |
| "EN CURSO" | Visita activa: tus reportes de esa póliza esperan entrega. |
| "COMPLETADA" | Visita cerrada: sola (todos los equipos entregados) o por la oficina con el botón "Cerrar visita" (en ese caso se muestra el motivo). |
| "PARCIAL" | La entrega cubrió menos equipos que los de la póliza. |
| "ENTREGADA" | Etiqueta del Resumen de visita. |

### 7.5 Términos de la app

| Término | Significado |
|---|---|
| **Entrega** | Firma única del cliente que cubre varios equipos de una póliza. |
| **Entrega parcial** | Entrega que cubre solo una parte de los equipos de la póliza. |
| **Visita** | Periodo de servicio programado de una póliza ("Visita 2/4"). |
| **Parque / Parque Total** | Todos los equipos de una póliza. |
| **Mis Tareas** | Equipos de una póliza asignados a ti. |
| **Grupo / Firma grupal** | Varios reportes del mismo cliente que se firman juntos. |
| **Sync / Sincronizar** | Enviar tus reportes al servidor y recibir novedades. |
| **Cola de sincronización** | Lista de lo que espera a enviarse. |
| **Contador de pulgadas** | Pulgadas lineales impresas que marca la impresora. |
| **Darkness** | Nivel de oscuridad de impresión. |
| **Ficha Tecnica** | Pantalla de datos de una impresora. |
| **Base local** | La información guardada en tu teléfono. |

---

## 8. Solución de problemas frecuentes

| Problema | Causa probable | Qué hacer |
|---|---|---|
| No puedo iniciar sesión | Sin internet, usuario o contraseña incorrectos, o usuario desactivado | Verifica internet y datos. Si dice "Usuario desactivado. Contacta a soporte.", habla con tu supervisor. |
| Olvidé mi contraseña | — | Contacta a soporte (la app no la restablece). |
| El botón dice "Sincronizando..." y no puedo entrar | La app descarga datos al abrirse | Espera hasta 10 segundos. |
| Aparece "Sesión expirada — inicia sesión para sincronizar" o "Token expirado" | Pasó más de un año desde tu última sincronización | Con internet: Mi Perfil → "CERRAR SESIÓN" → inicia sesión otra vez. Tus reportes y pendientes **se conservan** y se envían después (ver 2.3). |
| La app me llevó a la pantalla de inicio de sesión sin que yo cerrara sesión | El administrador desactivó tu usuario o revocó tu sesión | Tus datos y pendientes siguen en el teléfono. Si tu usuario está activo, inicia sesión de nuevo con internet; si dice "Usuario desactivado", habla con tu supervisor. |
| Hay pendientes en el teléfono que no se envían (aviso "de otro técnico") | Son de otro técnico que usó este teléfono | Se enviarán cuando esa persona inicie sesión. No los borres. |
| La cámara no escanea | Permiso de cámara negado, poca luz, QR dañado | Habilita el permiso en Ajustes de Android; usa "Manual" y escribe el serial. |
| "No se encontró ninguna impresora con ese serial." | Serial mal escrito, o la impresora no está descargada | Revisa el serial, sincroniza y busca de nuevo, o usa "Crear Nueva Impresora". |
| No veo el cliente, la póliza o la visita que debería | No se han descargado datos nuevos | Sincroniza (Centro de Sincronización) con internet. |
| No veo mi asignación ni la visita "EN CURSO" | La oficina aún no la activó o no sincronizaste | Sincroniza. Si sigue igual, avisa a la oficina (la visita se activa desde el panel administrador). |
| No me deja avanzar en la captura | Falta contador, casilla o foto | Lee el mensaje rojo: contador obligatorio, al menos una casilla de "Revision Tecnica" y al menos 1 foto. |
| "Se requiere la firma del cliente" | No se dibujó la firma | Haz que el cliente dibuje su firma. |
| No aparece "Envío por correo" al firmar (individual, grupal o entrega) | No había internet al abrir la pantalla | Es normal. El correo del cliente se enviará al sincronizar, pero no podrás escribir un correo adicional sin conexión. |
| No llegó el correo al cliente | El cliente no tiene correos registrados, el correo adicional estaba mal escrito, o no se sincronizó | Sincroniza; abre el reporte → "Enviar" y revisa los destinatarios; si no hay correos registrados, pide a la oficina que los agregue. |
| Elementos con "Error" en el Centro de Sincronización | El servidor los rechazó 3 veces (la falta de internet no cuenta) | Con internet toca "Reintentar N fallido(s)". Si el mensaje rojo persiste, toma una captura y avisa a soporte. |
| Quiero saber si un reporte ya llegó al servidor | — | Centro de Sincronización → ícono de reloj → "Historial de Sincronización" (4.25): ahí aparece con su fecha y hora. |
| No puedo eliminar un cliente | El cliente tiene elementos pendientes de sincronizar | Sincroniza primero (sección 6) y vuelve a intentarlo (ver 4.14). |
| Una visita de póliza sigue "EN CURSO" aunque ya entregué todo lo que atendí | Faltan equipos de la póliza por entregar y firmar | Revisa Detalle de Póliza → "Parque Total": la visita se cierra sola cuando todos los equipos tienen su reporte entregado y firmado (ver 5.2). |
| "Error de red: …" al sincronizar | Sin internet o señal débil | Cambia de Wi-Fi/datos o acércate a mejor señal y reintenta. |
| "Error del servidor (número)" | Falla del servidor | Reintenta más tarde; si persiste, avisa a soporte. |
| "Reimprimir" o "Enviar" dicen que no hay conexión | Requieren internet | Conéctate y vuelve a intentar. |
| Mi reporte no aparece en "Recientes" | Esa pestaña muestra solo tus últimos 20 reportes | Búscalo en el Detalle de Cliente → "Reportes" o en el Historial de Servicios de la impresora. |
| Un reporte pide "Reporte ya registrado" | Ya existe un reporte de esa impresora en la visita en curso | "Ver reporte existente" para revisarlo; "Crear de todas formas" solo si necesitas otro. |
| La entrega no me deja firmar o dice que no hay equipos | No hay reportes pendientes de entrega | Primero atiende los equipos (flujo 5.2). |
| Después de salir de una captura salen datos del reporte anterior | La app conserva en memoria lo capturado | Usa "Cancelar Reporte" (X o menú ⋮) para limpiar antes de salir (ver nota en 4.6). |
| Eliminé un cliente por error | "Eliminar Cliente" borra del teléfono sus equipos y reportes | Avisa de inmediato a soporte; sincroniza solo si te lo indican. |

---

## Lista de capturas

> Para tener buenas capturas, usa un usuario de prueba con **datos de ejemplo cargados**: al menos 2 clientes (uno con póliza vigente y otro sin póliza), una póliza **POR VENCER**, una póliza con **visita "EN CURSO"** y equipos asignados a ti y a otro técnico, y varios reportes de distinto estado. Cada fila indica los pasos y los datos que conviene tener.

| N.º | Pantalla | Ruta / pasos para llegar | Datos de ejemplo que conviene tener cargados |
|---|---|---|---|
| 01 | Inicio de sesión (vacío) | Abre la app sin sesión iniciada | Ninguno |
| 02 | Tarjeta de estado inferior del inicio de sesión | En inicio de sesión: toca "Forzar Sync" (estado "Sincronizando datos...") y, en otra captura, repite con el teléfono en modo avión ("Sin conexión al servidor") | Teléfono con y sin conexión |
| 03 | Aviso de error al iniciar sesión | Escribe una contraseña incorrecta y toca "INICIAR SESIÓN" | Usuario existente con contraseña errada |
| 04 | Mi Perfil completo con "CERRAR SESIÓN" · **REPETIR** (nueva leyenda de datos conservados y versión real de la app) | Panel principal → tu nombre o ícono de persona → desplázate al final | Técnico con firma guardada y al menos una sincronización hecha |
| 05 | Panel principal sin avisos · **REPETIR** (botón "Alertas Riesgo" desactivado con "Próximamente") | Inicia sesión con todo sincronizado | Cola de sincronización vacía y sin grupos abiertos |
| 06 | Panel principal con banners · **REPETIR** (botón "Alertas Riesgo" desactivado) | Panel principal con reportes pendientes y un grupo abierto | 1 o más reportes sin sincronizar; 1 grupo abierto de un cliente (reportes agrupados) |
| 07 | Hoja "FIRMA DEL TÉCNICO" con firma | Mi Perfil → "Actualizar Firma" → dibuja una firma | — |
| 08 | Mi Perfil con firma guardada | Después de "Guardar Firma" | — |
| 09 | Identificar Impresora con cámara activa | Panel principal → "Escanear QR" | Permiso de cámara concedido |
| 10 | Búsqueda manual con "Coincidencias" y etiqueta "EXACTO" | Identificar Impresora → "Manual" → escribe parte de un serial → "Buscar" | 2 o más impresoras con seriales parecidos (una con serial exacto) |
| 11 | Aviso "No se encontró ninguna impresora con ese serial." | Búsqueda manual con un serial inexistente | — |
| 12 | Confirmar Equipo con "Poliza Activa" | Escanea o busca una impresora con póliza vigente | Impresora de una póliza vigente |
| 13 | Confirmar Equipo con banner "Visita X/N en curso…" | Escanea una impresora de una póliza con visita en curso | Póliza con visita "EN CURSO" |
| 14 | Diálogo "Impresora asignada a otro técnico" | En Confirmar Equipo de una impresora asignada a otro técnico → "Crear reporte" | Equipo asignado a otro técnico en póliza con visita en curso |
| 15 | Diálogo "Reporte ya registrado" | En Confirmar Equipo de una impresora que ya tiene reporte pendiente de entrega → "Crear reporte" | Reporte "pending_delivery" de esa impresora en la visita activa |
| 16 | Captura de Servicio (parte superior) · **REPETIR** (con darkness decimal, por ejemplo 18.5) | Confirmar Equipo → "Crear reporte" | — |
| 17 | Captura de Servicio (casillas y fotos) | Desplázate hacia abajo, con casillas marcadas y 2 fotos | 2 fotos tomadas |
| 18 | Diálogo "Cancelar Reporte" | En Captura: toca la X o el menú ⋮ → "Cancelar Reporte" | — |
| 19 | Aviso "Se requiere mínimo 1 foto de evidencia" | En Captura: marca una casilla, escribe el contador y toca "Revisar Reporte" sin fotos | — |
| 20 | Resumen del Reporte · **REPETIR** (mostrando "Nivel de Darkness" con decimal, 18.5) | Captura → "Revisar Reporte" | Impresora con un servicio previo (para que la gráfica muestre "Anterior" y "Actual") |
| 21 | Firma de Conformidad con firma, datos y "Envío por correo" | Resumen → "Proceder a Firma" (con internet) | Impresora sin visita en curso; cliente con correos registrados |
| 22 | Botones inferiores de la firma | Misma pantalla, parte baja | — |
| 23 | Diálogo "Reporte Guardado" | Después de "Finalizar y Guardar Reporte" | — |
| 24 | Firma grupal | Panel principal → "Cerrar y firmar (N)" | Grupo abierto con 2 o más reportes de un cliente |
| 25 | Pantalla "Servicio registrado" | Después de "Guardar reporte" (póliza con visita en curso) o de agrupar un reporte | Póliza con visita en curso o cliente para agrupar |
| 26 | Pantalla "Entrega registrada" | Después de "Confirmar Entrega" | Entrega de al menos 2 equipos |
| 27 | Reportes — pestaña "Recientes" · **REPETIR** (con etiquetas de estado) | Panel principal → "Reportes" | Reportes del técnico en varios estados: firmado, pendiente de entrega, pendiente de firma grupal |
| 28 | Reportes — pestaña "Grupos abiertos" | Reportes → "Grupos abiertos" | 1 grupo abierto con 2 o más reportes |
| 29 | Reportes — pestaña "Póliza activa" | Reportes → "Póliza activa" | Póliza con visita en curso, equipos asignados al técnico, algunos atendidos |
| 30 | Ver Reporte | Reportes → "Recientes" → toca un reporte | Reporte firmado con fotos |
| 31 | Ver Reporte en edición | En Ver Reporte → ícono de lápiz | — |
| 32 | Diálogo "Enviar por correo" | Ver Reporte (estado "Signed") → "Enviar" (con internet) | Cliente con 1 o 2 correos registrados |
| 33 | Visor de fotos a pantalla completa | Ver Reporte → toca una foto | Reporte con fotos |
| 34 | Lista de Clientes | Panel principal → "Clientes" | Clientes con estados ESTABLE, RIESGO CRITICO y SIN POLIZA |
| 35 | Nuevo Cliente / Sitio | Clientes → botón + | — |
| 36 | Detalle de Cliente, pestaña "Impresoras" | Clientes → toca un cliente | Cliente con 2 o más impresoras |
| 37 | Detalle de Cliente, pestaña "Reportes" | Detalle de Cliente → "Reportes" | Cliente con varios reportes |
| 38 | Impresoras (inventario) | Panel principal → "Impresoras" | Impresoras "EN POLIZA" y "SIN POLIZA" |
| 39 | Nueva Impresora llena | Identificar Impresora → "Crear Nueva Impresora" | Cliente con planta y área |
| 40 | Ficha Tecnica | Confirmar Equipo → "Ver detalle" | Impresora con reportes (de preferencia con "Atencion" en otra captura) |
| 41 | Diálogo "Código QR de Impresora" | Ficha Tecnica → "Mostrar QR" | — |
| 42 | Historial de Servicios | Ficha Tecnica → "Ver Historial" | Impresora con 3 o más reportes de distintos tipos |
| 43 | Hoja "Filtrar por tipo de servicio" · **REPETIR** (opciones "Diagnóstico" e "Instalación" con acento) | Historial de Servicios → ícono de filtro | — |
| 44 | Lista de Pólizas con banner "Pendientes de entrega" · **REPETIR** (ya sin el botón +) | Panel principal → "Polizas" | Pólizas VIGENTE y POR VENCER; reportes pendientes de entrega |
| 45 | Detalle de Póliza — "Mis Tareas" · **REPETIR** (encabezado sin menú ⋮ ni "Cobertura"/"Trimestral") | Pólizas → toca una póliza | Equipos asignados al técnico, algunos con "COMPLETADO" |
| 46 | Detalle de Póliza — "Parque Total" · **REPETIR** (nuevo encabezado) | Detalle de Póliza → "Parque Total" | Equipos "Tú", de otro técnico y "Sin asignar" |
| 47 | Detalle de Póliza — "Visitas" · **REPETIR** (contador "N/M equipos entregados", nuevo encabezado y visita cerrada por la oficina con su motivo) | Detalle de Póliza → "Visitas" | Visita "EN CURSO" con algunos equipos entregados, visitas PROGRAMADA y COMPLETADA (una cerrada por la oficina con motivo), y una entrega "PARCIAL" |
| 48 | Entrega de póliza (carrusel) | Pólizas → "Iniciar entrega" | 2 o más reportes pendientes de entrega con foto |
| 49 | Botón de entrega verde y ámbar (parcial) | Misma pantalla, parte inferior, en dos casos | Un caso cubriendo todos los equipos pendientes y otro cubriendo solo una parte |
| 50 | Firma de entrega · **REPETIR** (la pantalla ahora tiene la tarjeta "Envío por correo"; se puede tomar con el teléfono sin conexión para mostrar la versión sin la tarjeta) | Entrega → "FIRMAR ENTREGA…" | — |
| 51 | Resumen de visita · **REPETIR** (ya sin el botón "Subir PDF de entrega") | Entrega registrada → "Ver resumen de visita" | Entrega firmada |
| 52 | Centro de Sincronización con pendientes | Panel principal → "Por Sync" (sin internet o antes de sincronizar) | Reportes, fotos, firmas y una entrega pendientes |
| 53 | Centro de Sincronización con "Error" | Provoca un error real del servidor en un elemento (3 intentos). Sincronizar sin conexión **ya no** genera "Error" | Elementos rechazados por el servidor, con motivo visible |
| 54 | Avisos de resultado · **REPETIR / AGREGAR** (éxito, "Sin conexión — los pendientes se conservan…" y sesión expirada) | Después de "INICIAR SINCRONIZACIÓN MASIVA" (con internet para el éxito; en modo avión para el aviso de sin conexión) | Pendientes en la cola; para la de sesión expirada, una prueba controlada con sesión vencida |
| 55 | Centro de Sincronización vacío ("Todo sincronizado") | Por Sync con todo enviado | Cola vacía |
| 56 | **NUEVA** — Historial de Sincronización (subidos recientemente) | Por Sync → ícono de reloj | Varios reportes ya sincronizados |
| 57 | **NUEVA** — Historial de Sincronización con "En error" y motivo | Por Sync → ícono de reloj, con elementos en "Error" | Al menos un elemento rechazado por el servidor |
| 58 | **NUEVA** — Aviso "¿Cerrar sesión?" con pendientes | Mi Perfil → "CERRAR SESIÓN" con elementos pendientes | Al menos 1 elemento pendiente en la cola |
| 59 | **NUEVA** — Firma de entrega con "Envío por correo" y "Correo adicional" | Entrega → "FIRMAR ENTREGA…" (con internet) → "Agregar otro" | Póliza con visita en curso y cliente con correos registrados |

> **Resumen de capturas a repetir o agregar:** repetir 04, 05, 06, 16, 20, 27, 43, 44, 45, 46, 47, 50, 51 y 54 (y 53 con el nuevo procedimiento); agregar 56, 57, 58 y 59. Las capturas 56 a 59 se numeraron al final para no cambiar la numeración de las capturas ya tomadas; el resto (01–03, 07–15, 17–19, 21–26, 28–42, 48, 49, 52 y 55) sigue vigente sin cambios.

---

## Pendientes de confirmar

Estos son los únicos puntos que siguen sin resolverse y requieren una confirmación o prueba del equipo de Servicios Main PC (los códigos R-xxx repetidos y el cierre manual de visitas ya quedaron resueltos y documentados en 7.1, 4.21 y 5.2):

1. `[VERIFICAR]` **APK vigente a repartir** (nombre y versión). En los registros del proyecto el último generado es `servicios_mainpc_v4.apk`, anterior a los cambios descritos en este manual; hay que generar y repartir un APK nuevo (incluye el permiso de Internet en la compilación de producción, la tarjeta "Envío por correo" en la firma de entrega y el motivo de cierre de visita).
2. `[VERIFICAR]` **Pantalla o aviso con el permiso de cámara negado** (4.4): el código no muestra un aviso propio, depende del componente de escaneo; hay que probarlo en un teléfono con el permiso denegado.
3. `[VERIFICAR]` **Hora en "Ultima sync" del Panel principal** (4.2): hoy puede mostrarse en blanco; confirmar si se corrige o se retira ese texto.
