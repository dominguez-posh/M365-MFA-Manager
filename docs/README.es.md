🌐 [English](../README.md) · [Deutsch](README.de.md) · **Español** · [Français](README.fr.md) · [Italiano](README.it.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Polski](README.pl.md)

# M365 MFA Administration Tool

Con esta herramienta, los administradores y el personal del servicio de asistencia configuran la **autenticación multifactor (MFA) en nombre de otros usuarios**, por ejemplo una llave FIDO2, una tarjeta TOTP o un código de acceso temporal. Además, muestra de un vistazo lo bien protegida que está una cuenta de usuario.

> [!NOTE]
> Las capturas de pantalla muestran la interfaz en inglés. Puede cambiar la interfaz a español en la parte superior derecha.

![Ventana principal de M365 MFA Administration Tool](images/en/main-window.png)

## Contenido

- [De un vistazo](#de-un-vistazo)
- [Inicio rápido](#inicio-rápido)
- [Guía paso a paso](#guía-paso-a-paso)
- [¿Qué método usar y cuándo?](#qué-método-usar-y-cuándo)
- [Crear una cuenta de emergencia](#crear-una-cuenta-de-emergencia)
- [Guía de MFA por correo](#guía-de-mfa-por-correo)
- [Informe MFA del inquilino](#informe-mfa-del-inquilino)
- [Importación masiva de tokens TOTP](#importación-masiva-de-tokens-totp)
- [Inventario de tokens](#inventario-de-tokens)
- [Temporary Access Pass masivo](#temporary-access-pass-masivo)
- [Campaña MFA y clasificación de cuentas](#campaña-mfa-y-clasificación-de-cuentas)
- [Baja masiva](#baja-masiva)
- [Ayuda, configuración y actualizaciones](#ayuda-configuración-y-actualizaciones)
- [Preguntas frecuentes y solución de problemas](#preguntas-frecuentes-y-solución-de-problemas)
- [Seguridad](#seguridad)
- [Para administradores: requisitos y permisos](#para-administradores-requisitos-y-permisos)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Añadir un idioma](#añadir-un-idioma)

---

## De un vistazo

| | Función |
|---|---|
| 🔍 | **Buscar usuarios** – por nombre, correo electrónico, UPN o ID de objeto |
| 🚦 | **Semáforo de MFA** – muestra al instante si una cuenta está bien, débilmente o nada protegida, con una recomendación |
| 👑 | **Roles de administrador** – muestra si el usuario tiene derechos administrativos |
| 📋 | **Ver y eliminar métodos MFA** – todos los métodos registrados con fecha y detalles |
| ➕ | **Configurar métodos** – llave FIDO2, tarjetas TOTP, Temporary Access Pass y MFA ficticia |
| ✉️ | **Guía de MFA por correo** – envía a los usuarios sin MFA o con MFA débil una guía paso a paso para la aplicación Microsoft Authenticator, en su idioma y con vista previa |
| 📊 | **Informe MFA del inquilino** – estado MFA y último inicio de sesión de todos los usuarios como semáforo, con búsqueda, filtros y exportación a Excel en color |
| 📥 | **Importación masiva de TOTP** – importar tokens TOTP de hardware (SHA-1 o SHA-256) desde un archivo CSV, con importación de prueba, exportación a Excel y deshacer |
| 🗂️ | **Inventario de tokens** – todos los tokens TOTP de hardware del inquilino: asignar tokens libres, quitar asignaciones, eliminar |
| 🎫 | **TAP masivo** – Temporary Access Pass para muchos usuarios a la vez (CSV o grupo) con exportación a Excel |
| 🆘 | **Cuenta de emergencia** – crear un acceso de emergencia (break-glass) con llave FIDO2 y contraseña desconocida |
| 🌐 | **Multilingüe** – inglés (predeterminado), alemán, español, francés, italiano, portugués, neerlandés y polaco |

---

## Inicio rápido

1. Copie la carpeta completa en su equipo (los archivos deben permanecer juntos).
2. **Haga doble clic en `Start.cmd`.**
3. En la parte superior derecha, cambie el idioma a **Español** y haga clic en **"Iniciar sesión"**. Inicie sesión con su propia cuenta de administrador.

> [!TIP]
> Para un acceso rápido, cree un acceso directo en el escritorio a `Start.cmd` (clic derecho → *Crear acceso directo*).

En el primer inicio de sesión, la herramienta comprueba si faltan componentes necesarios. Si es así, los enumera y pregunta una sola vez si deben instalarse; la instalación se ejecuta en segundo plano (uno o dos minutos) y se muestra en el registro. Después, Microsoft solicita una única vez el consentimiento para los permisos de la herramienta.

---

## Guía paso a paso

### 1. Elegir el idioma e iniciar sesión

La interfaz se inicia en **inglés**. Con el cuadro de selección en la parte superior derecha, junto a "Sign in", puede cambiar el idioma en cualquier momento, sin reiniciar. La selección se guarda para su usuario de Windows y se aplica en el siguiente inicio.

Haga clic en **"Iniciar sesión"** en la parte superior derecha. Tras iniciar sesión correctamente, aparece en verde *"Conectado como …"* junto con el inquilino. **"Cerrar sesión"** finaliza la sesión; esto también ocurre automáticamente al cerrar la ventana.

### 2. Buscar un usuario

En el cuadro **"1. Buscar usuario"**, escriba el comienzo de un nombre, una dirección de correo electrónico o el UPN y pulse **Intro** (o haga clic en **"Buscar"**).

- **Un resultado:** el usuario se abre directamente.
- **Varios resultados:** se despliega una lista debajo del cuadro de búsqueda; haga clic en el usuario deseado. Con **Esc** o un clic fuera, la lista se cierra.

### 3. Entender el estado de MFA

A la derecha, en **"Usuario seleccionado"**, el **semáforo de MFA** muestra lo bien protegida que está la cuenta:

| Semáforo | Significado | ¿Qué hacer? |
|---|---|---|
| 🟢 **MFA fuerte (resistente al phishing)** | Llave FIDO2, clave de acceso o Windows Hello presente | Todo correcto. |
| 🟢 **MFA fuerte** | App Authenticator o tarjeta/app TOTP presente | Correcto. Para administradores se recomienda además FIDO2. |
| 🟡 **Solo MFA débil** | Solo SMS o llamada | Configure un método mejor y después elimine SMS/llamada. |
| 🟡 **Solo MFA ficticia** | La cuenta está bloqueada como protección (ver [MFA ficticia](#qué-método-usar-y-cuándo)) | Configure un método real para poder usarla. |
| 🟡 **Solo Temporary Access Pass** | Solo un código de acceso temporal | El usuario debe usarlo ahora para configurar un método permanente. |
| 🔴 **Sin MFA – solo contraseña** | Sin segundo factor | Configure un método con urgencia. |

Debajo del semáforo aparecen recomendaciones concretas, por ejemplo *"También hay SMS/llamada registrados y se pueden eliminar"*.

Más abajo, **"Roles administrativos"** muestra si el usuario tiene derechos de administrador. Con **"Mostrar"** se despliega la lista. Para cada rol se indica también si está activo de forma permanente, asignado a través de un grupo o solo activable mediante PIM.

### 4. Ver y eliminar métodos MFA

A la izquierda, en **"2. Métodos MFA registrados"**, aparecen todos los métodos del usuario. Al hacer clic en un método se muestran debajo **todos los detalles** (p. ej. modelo de dispositivo, número de serie, fecha de creación).

Para eliminar un método, selecciónelo y haga clic en **"Eliminar método"**. Antes de eliminar aparece una confirmación. La contraseña no se puede eliminar.

> [!NOTE]
> Microsoft aplica los cambios con unos segundos de retraso. La herramienta espera automáticamente hasta que la lista muestre el estado nuevo. Si es necesario, haga clic en **"Actualizar"**.

### 5. Configurar un método nuevo

A la derecha, en **"3. Configurar método"**, seleccione el método deseado:

![Selección del método MFA](images/en/select-method.png)

Según el método, aparecen los campos correspondientes (p. ej. el número de serie) y una breve indicación. Después haga clic en **"Iniciar configuración"** y confirme. El resultado aparece en el **registro** y la lista de métodos se actualiza automáticamente.

---

## ¿Qué método usar y cuándo?

| Método | ¿Cuándo usarlo? | ¿Qué ocurre? |
|---|---|---|
| **Llave de seguridad FIDO2** | El usuario recibe una llave FIDO2 (p. ej. YubiKey). El método más seguro, especialmente para administradores. | Conecte la llave e introduzca el número de serie. Windows pide el **PIN** de la llave y que la **toque**. La llave se llamará `FIDO2-<número de serie>`. |
| **Tarjeta TOTP con secreto fijo** | El usuario recibe una tarjeta de códigos cuyo secreto suministró el fabricante. | Introduzca el número de serie y el secreto. La tarjeta se crea, se asigna al usuario y se activa de inmediato. |
| **Tarjeta TOTP programable** | El usuario recibe una tarjeta de códigos que se programa uno mismo (p. ej. con la app del fabricante). | Introduzca el número de serie. La herramienta genera un secreto nuevo y muestra el **código QR y el secreto**. Programe la tarjeta con ellos y cierre la vista con ✕. |
| **Temporary Access Pass (TAP)** | El usuario debe configurar él mismo Authenticator o una clave de acceso, pero aún no tiene ningún método, o lo ha perdido. | Se genera un código **válido desde ahora durante 2 horas** y de uso múltiple. Aparece en grande en un recuadro amarillo y se puede copiar. Un TAP existente se reemplaza. |
| **MFA ficticia** | Se quiere proteger una cuenta que (todavía) nadie usa, p. ej. una cuenta de emergencia o de servicio nueva. | Se registra un método de código cuya clave se destruye de inmediato. Al iniciar sesión se exige una MFA que nadie puede cumplir, lo que protege la cuenta. |

> [!IMPORTANT]
> **Los TAP, secretos y códigos QR se muestran una sola vez.** No se escriben en el registro y no se pueden recuperar más tarde. Si guarda un código QR con "Guardar código QR …", el archivo contiene el secreto: elimínelo después de programar.

### MFA ficticia con hrdnr

Si el inquilino se administra con hrdnr, el secreto de un token de MFA ficticia puede **guardarse cifrado** en lugar de descartarse. Así, en caso de emergencia, hrdnr puede mostrar el código actual de 6 dígitos sin tener que configurar otro método.

- **Clave de hrdnr (opcional):** aparece al seleccionar «MFA ficticia». Pegue la clave pública de hrdnr (**Usuarios y MFA → Clave para el M365 MFA Manager**, formato `hrdnr-fakemfa:1:…`) o haga clic en **«Cargar del inquilino»** si hrdnr la ha guardado en el inquilino (extensión `com.hrdnr.fakeMfaKey` de la organización). La herramienta recuerda la clave por inquilino.
- El secreto se cifra con esta clave (RSA-OAEP-SHA256) y se guarda en la extensión abierta `com.hrdnr.fakeMfa` del usuario (número de serie, ID de clave, secreto cifrado). Solo hrdnr tiene la clave privada; la herramienta no puede volver a leer el secreto.
- Sin clave, la MFA ficticia funciona como antes: el secreto se descarta de inmediato.

---

## Crear una cuenta de emergencia

Una **cuenta de emergencia (break-glass)** es un acceso de emergencia que permite entrar en el inquilino aunque los accesos de administrador normales fallen (p. ej. por una directiva de acceso condicional errónea).

Abra arriba **Herramientas ▾ → "Cuenta de emergencia …"**:

![Diálogo "Crear cuenta de emergencia"](images/en/breakglass-dialog.png)

1. Seleccione el **dominio** en el que se creará la cuenta.
2. Decida si la cuenta recibe el rol **Global Administrator** (recomendado, preseleccionado).
3. Conecte la **llave FIDO2** e introduzca su número de serie.
4. Haga clic en **"Crear cuenta"**.

A continuación, la herramienta automáticamente:

- crea la cuenta con una **contraseña aleatoria** (255 caracteres; nunca se muestra ni se guarda, nadie la conoce)
- cambia el nombre de la cuenta al ID de objeto único
- asigna el rol Global Administrator
- protege la cuenta de inmediato con **MFA ficticia**
- **registra la llave FIDO2** (Windows pide PIN y que la toque) y después vuelve a eliminar la MFA ficticia

Al final, un resumen muestra lo realizado y la nueva cuenta se muestra directamente.

> [!WARNING]
> **Después, complete manualmente:**
> - **Excluya** la cuenta **de todas las directivas de acceso condicional**.
> - Configure una **alerta de inicio de sesión** para detectar cualquier uso.
> - Guarde la llave FIDO2 en un lugar seguro (p. ej. una caja fuerte).

Si el registro de FIDO2 falla o se cancela, la cuenta sigue protegida con MFA ficticia. La llave se puede añadir más tarde en **"3. Configurar método → Llave de seguridad FIDO2"**.

---

## Guía de MFA por correo

Si un usuario **no tiene MFA o solo tiene MFA débil** (semáforo rojo o amarillo), junto al estado de MFA aparece el botón **"Enviar guía …"**. Envía al usuario un correo con una guía sencilla paso a paso: abrir aka.ms/mfasetup, agregar la aplicación Microsoft Authenticator y escanear el código QR. Si el usuario no puede o no quiere usar la aplicación, el correo le pide que contacte con el departamento de TI, simplemente respondiendo al correo.

![Vista previa de la guía de MFA](images/en/mfa-guide-dialog.png)

- **Primero la vista previa:** el correo se muestra exactamente como se enviará. Solo se envía tras **"Enviar correo"** y una confirmación.
- **Idioma del usuario:** el correo se redacta en el idioma preferido del usuario en Entra ID (si no, en el del inquilino; si no, en inglés) y se puede cambiar en la vista previa.
- **Remitente:** de forma predeterminada, su propio buzón. También puede indicar un buzón compartido (p. ej. el de TI) para el que tenga el permiso *Enviar como*; las respuestas llegarán allí. Se recuerda el último remitente.
- **Imágenes:** las capturas se incrustan en el correo como datos adjuntos en línea (Base64): no se carga nada de Internet y también se muestran en Outlook.
- **Fecha de envío en el objeto de usuario:** tras el envío, la fecha, el remitente y el idioma se guardan en una open extension del usuario (`com.m365mfatool.mfaGuide`). Las open extensions solo existen en Entra ID: también se pueden escribir en usuarios sincronizados (híbridos) y Entra Connect / Cloud Sync nunca las sobrescribe, a diferencia de `extensionAttribute1–15`. La fecha se muestra bajo el semáforo y en el informe MFA (columna **"Guía enviada"**).
- **Historial de envíos (número y horas):** una segunda open extension `com.m365mfatool.mfaGuideHistory` cuenta cada envío (`sentCount`) y guarda las horas de los últimos 20 envíos con remitente e idioma (`entries`, además de `firstSentDateTime`/`lastSentDateTime`). El historial se muestra como información sobre herramientas en el estado de la guía y en el informe MFA del tenant (columna **"Cantidad"**). hrdnr lee y escribe la misma extensión.

Las capturas del smartphone del correo proceden de la documentación de Microsoft (MicrosoftDocs/entra-docs, licencia MIT); todas las capturas están anonimizadas.

---

## Informe MFA del inquilino

Haga clic en **"Informe MFA …"** arriba a la izquierda para comprobar de una vez el estado MFA de **todos los usuarios del inquilino** (o de los miembros de un grupo, incluidos los grupos anidados).

![Informe de estado MFA del inquilino](images/en/tenant-report.png)

1. Elija el alcance: **"Todos los usuarios"** o **"Miembros de un grupo (incl. grupos anidados)"** (busque el grupo por el inicio de su nombre o por el ID de objeto). De forma predeterminada solo se incluyen cuentas habilitadas y ninguna cuenta de invitado.
2. Haga clic en **"Crear informe"**. La lista se va llenando mientras se leen los métodos (20 usuarios por solicitud de Graph). **"Cancelar"** se detiene tras el bloque actual.
3. Los mosaicos muestran la cantidad por color del semáforo; **al hacer clic en un mosaico se filtra** la lista. Además puede **buscar** (nombre, UPN, correo, roles, métodos, valoración, departamento) y mostrar **"Solo administradores"**.
   Las columnas **"Último inicio de sesión"** y **"Días desde"** muestran si una cuenta se usa realmente. Las cuentas sin inicio de sesión desde hace más de 90 días o que nunca han iniciado sesión se resaltan en rojo, se cuentan en un mosaico propio y se pueden mostrar con **"Solo inactivos (> 90 días o nunca)"**.
4. **"Exportar a Excel …"** guarda las entradas mostradas actualmente como archivo `.xlsx` en los colores del semáforo, con una hoja de resumen. No se necesita Excel ni ningún módulo adicional.
5. **Doble clic** en un usuario cierra el informe y abre el usuario en la ventana principal para editarlo. El informe se conserva hasta cerrar la sesión.

| Semáforo | Significado |
|---|---|
| 🔴 **Rojo** | Sin MFA (solo contraseña), **o** rol administrativo solo con MFA insegura (SMS/llamada, TAP o MFA ficticia) |
| 🟡 **Amarillo** | Solo MFA insegura (SMS/llamada, TAP o MFA ficticia), **o** administrador sin MFA resistente al phishing (FIDO2, passkey, Windows Hello) |
| 🟢 **Verde** | MFA segura; para administradores, resistente al phishing |

Como roles administrativos cuentan los roles activos y los elegibles mediante PIM (marcados con "(PIM)"), así como los roles asignados a través de grupos.

**Sin interfaz gráfica** (p. ej. como tarea programada mensual) el informe puede crearse desde la línea de comandos; el inicio de sesión sigue siendo interactivo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Start-M365MfaTool.ps1 -Report -OutFile C:\Informes\MFA.xlsx
```

Opciones: `-Group "<nombre o ID de objeto>"` (miembros de un grupo en lugar de todos los usuarios), `-IncludeDisabled`, `-IncludeGuests`, `-Language es`. Código de salida 0 si todo va bien, 1 en caso de error.

---

## Importación masiva de tokens TOTP

Para tokens TOTP de hardware con archivo de semillas del fabricante (p. ej. tokens con pantalla tipo llavero), abra arriba **Herramientas ▾ → "Importar TOTP …"**.

1. **"Ejemplo"** guarda un CSV de ejemplo con las columnas esperadas. Una línea por token:

   ```csv
   Secret;SerialNumber;UPN
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000001;ana.ejemplo@contoso.com
   JBSWY3DPEHPK3PXPJBSWY3DPEHPK3PXP;SN1000002;
   ```

   Separador `;` o `,`; el orden de las columnas no importa. **UPN es opcional**: una línea sin UPN solo añade el token al inventario; asígnelo después en el [inventario de tokens](#inventario-de-tokens), o elija en **Tokens sin UPN** los **miembros de un grupo** o los **usuarios de una lista CSV**: la comprobación reparte entonces los tokens en el orden del archivo, uno por usuario, y la importación los activa. Columnas opcionales: `Manufacturer`, `Model`.
2. **"Seleccionar CSV …"** carga el archivo. Elija el **algoritmo** (SHA-1 o SHA-256) y el **intervalo** (30 o 60 segundos); ambos deben coincidir con los tokens (véase el pedido o el archivo de semillas).
3. **"Comprobar"** comprueba cada línea sin cambiar nada: secreto Base32, números de serie duplicados, si el usuario existe y si el número de serie ya está asignado en el inquilino. Las líneas se muestran en verde/amarillo/rojo.
4. **"Importar"** crea los tokens sin errores en el inventario, los asigna a los usuarios y los activa de inmediato. Las líneas con errores se omiten; un token fallido se revierte. Cada token aparece en el registro (sin secreto).
5. **"Exportar a Excel …"** guarda la lista de resultados (número de serie → usuario) como comprobante y documento de entrega. **"Deshacer"** elimina de nuevo los tokens creados en la última ejecución de los usuarios y del inventario (disponible hasta la próxima importación de prueba).

Cambiar el archivo, el algoritmo, el intervalo o el reparto requiere una nueva comprobación.

---

## Inventario de tokens

**Herramientas ▾ → "Inventario de tokens …"** muestra todos los tokens TOTP de hardware del inquilino: tokens libres (amarillo), asignados y activados (verde), con modelo, algoritmo, intervalo y usuario asignado. Con búsqueda y filtro por libre/asignado.

- **"Asignar …"**: seleccione primero un usuario en la ventana principal y luego un token libre. Introduzca el código que muestra el token en ese momento: se asigna y activa en un solo paso (como en el portal de Entra).
- **"Repartir …"**: reparte todos los tokens libres entre los miembros de un grupo o los usuarios de una lista CSV, uno a cada uno en orden de número de serie, **sin activación**, porque los secretos ya no se conocen. Cada usuario activa su token en [aka.ms/mysecurityinfo](https://aka.ms/mysecurityinfo) introduciendo el código que muestra, o lo hace usted con **"Activar …"**. La lista de asignaciones (número de serie → usuario) se ofrece justo después como Excel.
- **"Activar …"**: activa un token asignado pero aún no activado con el código que muestra.
- **"Desasignar"**: el usuario ya no puede iniciar sesión con el token; permanece en el inventario como token libre.
- **"Eliminar"**: quita el token del inventario (un token asignado se quita primero de su usuario).

---

## Temporary Access Pass masivo

**Herramientas ▾ → "TAP masivo …"** crea un Temporary Access Pass para muchos usuarios a la vez, p. ej. para una oleada de incorporaciones.

1. Elija los usuarios: un **archivo CSV** (columna `UPN` o un UPN por línea) o los **miembros de un grupo** (incl. grupos anidados).
2. Defina la **validez** (10–43200 minutos) y si el pase es de **uso único**.
3. **"Comprobar"** resuelve los usuarios sin cambiar nada. **"Crear"** crea después un pase por usuario; un pase existente del usuario se reemplaza.
4. **"Exportar a Excel …"** guarda la lista con los pases; los contiene en texto claro, así que guárdela solo en un lugar protegido y elimínela tras la entrega. Los pases nunca se escriben en el registro.

## Campaña MFA y clasificación de cuentas

**Herramientas ▾ → "Campaña MFA …"** (o **"Clasificar cuentas …"**) abre una ventana con dos pestañas que usa los mismos datos que el informe MFA (o **"Cargar usuarios"**).

- **"Clasificar cuentas"**: marque como **"No es una persona"** cada cuenta sin una persona detrás (buzón compartido, cuenta de servicio, sala o prueba). Se guarda en el objeto de usuario (extensión abierta `com.m365mfatool.accountClass`) y se muestra también en la ventana principal (**"Tipo de cuenta"**) y en el informe MFA. La campaña omite estas cuentas.
- **"Campaña"**: contadores (grupo objetivo, nunca contactados, contactados), filtros por semáforo y último contacto; seleccione usuarios y envíe la guía por **correo** y/o **Teams** (mensaje de chat 1:1 desde su cuenta).

Cada envío se guarda en el usuario: número, primera y última fecha y los últimos 20 envíos con fecha, remitente, idioma y canal.

---

## Baja masiva

**Herramientas ▾ → "Baja masiva …"** quita a la vez los métodos MFA de muchos usuarios, p. ej. por bajas de empleados o tras cuentas comprometidas.

1. Elija los usuarios: un **archivo CSV** (columna `UPN` o un UPN por línea) o los **miembros de un grupo**.
2. Elija las acciones: **quitar todos los métodos MFA**, **revocar sesiones** (el usuario queda desconectado en todas partes) y opcionalmente **deshabilitar cuenta**.
3. **"Comprobar"** resuelve los usuarios y muestra cuántos métodos y roles de administrador tiene cada uno, sin cambiar nada. Su propia cuenta siempre se omite.
4. **"Ejecutar baja"**, tras confirmar el resumen.
5. **"Exportar a Excel …"** guarda la lista de resultados como comprobante.

> [!WARNING]
> Los métodos quitados no se pueden restaurar. Los usuarios tienen que registrarlos de nuevo, p. ej. con un Temporary Access Pass.

---

## Ayuda, configuración y actualizaciones

- **"Ayuda"** arriba en cada ventana abre un panel lateral: *qué hace, cuándo usarlo, qué necesita, paso a paso* y *resultado*. Además, cada botón y campo tiene una descripción emergente.
- En el primer inicio, una **pantalla de bienvenida** explica los tres pasos (se puede desactivar).
- **Herramientas ▾ → "Configuración …"**: algoritmo e intervalo predeterminados de los tokens TOTP, validez y uso único predeterminados de los TAP, buzón remitente de la guía MFA y, opcionalmente, un **inquilino** (ID o dominio) para cuentas invitadas.
- La ventana principal muestra el **último inicio de sesión**, el **historial** del registro de auditoría, un **comprobante Excel** del usuario y, para administradores, **"Comprobar exclusión CA"**.
- Si el método está deshabilitado en la directiva de métodos de autenticación del inquilino, aparece un aviso amarillo antes de empezar.
- Cuando hay una versión nueva, aparece arriba el botón **"Actualizar …"**: descarga e instala la versión (registros y configuración se conservan); después reinicie la herramienta.

---

## Preguntas frecuentes y solución de problemas

**Al hacer doble clic en `Start.cmd` no ocurre nada o aparece un error.**
La herramienta solo funciona en Windows. Si la carpeta se copió de Internet, Teams o un archivo ZIP, los archivos pueden estar bloqueados. Ejecute una vez en PowerShell dentro de la carpeta: `Get-ChildItem -Recurse | Unblock-File`.

**El inicio de sesión vuelve a pedir consentimiento.**
Ocurre una vez tras una actualización, cuando la herramienta necesita permisos nuevos. Todos los permisos se solicitan al iniciar sesión; después no aparece ningún otro diálogo de inicio de sesión.

**El registro indica que hay una versión más reciente.**
Al iniciar, la herramienta compara su versión con la última publicada en GitHub (solo una línea en el registro, no se descarga nada). Descargue la nueva versión desde la página de releases y reemplace la carpeta.

**Un método recién creado o eliminado no se muestra de inmediato.**
Microsoft necesita unos segundos. La herramienta espera automáticamente hasta unos 16 segundos; después, si es necesario, haga clic en **"Actualizar"**.

**FIDO2: "Fido credential policy …" o "no está habilitado".**
FIDO2 no está habilitado en el inquilino. Un administrador debe habilitarlo en la directiva de métodos de autenticación (ver [requisitos](#para-administradores-requisitos-y-permisos)).

**FIDO2: "El UPN es demasiado largo".**
FIDO2 permite un máximo de 64 caracteres para el nombre de inicio de sesión (UPN).

**Tarjeta TOTP: "Un token con el número de serie … ya está asignado a …".**
La tarjeta ya pertenece a otro usuario. Elimínela primero allí.

**Mensaje de error con "Authorization_RequestDenied" o "Forbidden".**
A su cuenta le falta un rol de administrador (ver [roles](#para-administradores-requisitos-y-permisos)).

Cada acción aparece con su hora en el **registro** de la parte inferior derecha. Además, se guarda de inmediato en un archivo de registro diario en la carpeta de la herramienta, p. ej. `Logs\2026-10-12.log` (si la carpeta no admite escritura: `%LOCALAPPDATA%\M365MfaTool\Logs`), útil en caso de consultas.

**Informe MFA: las columnas de último inicio de sesión están vacías.**
Para ello se necesitan una licencia **Entra ID P1/P2**, el permiso `AuditLog.Read.All` y un rol que pueda leer los datos de inicio de sesión (p. ej. **Lector de informes**). Sin ellos, el informe se crea igualmente, solo que sin esta información; el registro indica el motivo.

---

## Seguridad

- **Sin secretos en el registro:** los TAP, secretos y contraseñas nunca se registran ni se guardan en disco.
- **Contraseñas desconocidas:** las contraseñas de las cuentas de emergencia se generan aleatoriamente y nunca se muestran.
- **Confirmaciones:** cada cambio debe confirmarse; las confirmaciones tienen "No" como opción predeterminada.
- **Limpieza en caso de error:** si falla la configuración de una tarjeta TOTP, la herramienta elimina automáticamente las entradas creadas a medias.

> [!CAUTION]
> Realice acciones administrativas solo de acuerdo con su proceso interno de aprobación y seguridad.

---

## Para administradores: requisitos y permisos

### Requisitos del sistema

- Windows con **Windows PowerShell 5.1** (preinstalado; PowerShell 7 no es compatible porque la interfaz usa WPF)
- Acceso a Internet en el primer inicio para instalar los módulos de PowerShell (solo para el usuario actual, sin derechos de administrador):
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Identity.SignIns` y `DSInternals.Passkeys` **1.0.6** (FIDO2)
  - `QRCodeGenerator` (códigos QR para tarjetas TOTP programables)

  También se pueden instalar de antemano con `Install-Prerequisites.ps1`.
- Para FIDO2, la llave debe estar conectada al **equipo local** (por RDP solo con redirección de WebAuthn).

### Permisos de Graph (delegados)

Todos los permisos se solicitan una sola vez al iniciar sesión, por lo que no aparece ningún otro diálogo de inicio de sesión durante el trabajo:

| Permiso | Para qué |
|---|---|
| `User.Read.All` | Buscar usuarios |
| `UserAuthenticationMethod.Read.All` | Mostrar métodos MFA |
| `UserAuthenticationMethod.ReadWrite.All` | Configurar y eliminar métodos MFA |
| `Policy.ReadWrite.AuthenticationMethod` | Inventario de tokens: crear, asignar y eliminar tarjetas TOTP, tokens TOTP importados y MFA ficticia |
| `RoleManagement.Read.Directory` | Mostrar los roles de administrador de un usuario |
| `User.ReadWrite.All` | Cuenta de emergencia; guardar la fecha de envío de la guía MFA y el secreto cifrado de la MFA ficticia en el objeto de usuario |
| `Domain.Read.All` | Cuenta de emergencia: mostrar dominios para seleccionar |
| `RoleManagement.ReadWrite.Directory` | Cuenta de emergencia: asignar Global Administrator |
| `GroupMember.Read.All` | Informe MFA: elegir un grupo como ámbito, resolver roles asignados mediante grupos |
| `AuditLog.Read.All` | Informe MFA: último inicio de sesión |
| `Policy.Read.All` | Aviso si un método está deshabilitado en el inquilino; comprobación de acceso condicional |
| `Chat.Create` | Guía MFA como mensaje de Teams: chat 1:1 con el usuario |
| `ChatMessage.Send` | Guía MFA como mensaje de Teams: enviar el mensaje |
| `Mail.Send` | Guía MFA desde el propio buzón |
| `Mail.Send.Shared` | Guía MFA desde un buzón compartido |
| `Organization.Read.All` | Cargar la clave hrdnr desde el inquilino |

Si un permiso no se concedió (consentimiento rechazado), la función afectada lo indica; cierre la sesión y vuelva a iniciarla para concederlo.

El último inicio de sesión requiere además una licencia **Entra ID P1/P2** y un rol que pueda leer datos de inicio de sesión, p. ej. **Reports Reader**, **Security Reader** o **Global Reader**. Se muestra el último inicio de sesión correcto (interactivo o no interactivo); Microsoft lo registra desde diciembre de 2023, los valores anteriores son el último intento.

Guardar la fecha de envío de la guía MFA requiere un rol que pueda modificar usuarios, p. ej. **User Administrator**.

### Roles de Entra necesarios para su propia cuenta

| Tarea | Rol |
|---|---|
| Gestionar métodos de usuarios normales, TAP | **Authentication Administrator** |
| Gestionar métodos de administradores | **Privileged Authentication Administrator** |
| Tarjetas TOTP, importación TOTP y MFA ficticia | además **Authentication Policy Administrator** |
| Cuenta de emergencia | **Global Administrator** (o Privileged Role Administrator + User Administrator) |

### Configuración del inquilino

En la **directiva de métodos de autenticación** (Centro de administración de Entra → Protección → Métodos de autenticación) deben estar habilitados los métodos usados:

- **Clave de acceso (FIDO2)**
- **Tokens OATH de hardware** (para tarjetas TOTP y MFA ficticia)
- **Temporary Access Pass** – vigencia máxima de al menos 2 horas

### Notas

- Algunas funciones usan la **API beta** de Microsoft Graph (p. ej. para tokens OATH de hardware), que puede cambiar.
- Los roles elegibles mediante PIM solo se muestran con Entra ID P2.
- El idioma elegido se guarda en `%APPDATA%\M365MfaTool\settings.json`.

---

## Estructura del proyecto

| Archivo | Contenido |
|---|---|
| `Start.cmd` | Iniciador por doble clic |
| `Start-M365MfaTool.ps1` | Interfaz, gestión de estado y eventos |
| `UI/Theme.xaml` | Aspecto común de todas las ventanas |
| `UI/MainWindow.xaml` | Diseño de la ventana principal |
| `UI/BreakGlassDialog.xaml` | Diálogo para nuevas cuentas de emergencia |
| `UI/TenantReportWindow.xaml` | Ventana del informe MFA |
| `UI/TotpImportWindow.xaml` | Ventana de la importación masiva de TOTP |
| `UI/TokenInventoryWindow.xaml` | Ventana del inventario de tokens |
| `UI/BulkTapWindow.xaml` | Ventana del Temporary Access Pass masivo |
| `UI/MfaGuideDialog.xaml` | Diálogo de vista previa de la guía de MFA |
| `UI/BulkOffboardWindow.xaml` | Ventana de la baja masiva |
| `UI/CampaignWindow.xaml` | Ventana de la campaña MFA y la clasificación de cuentas |
| `UI/SettingsDialog.xaml` | Diálogo de configuración |
| `UI/HistoryDialog.xaml` | Historial de un usuario (registro de auditoría) |
| `Modules/Graph.psm1` | Inicio de sesión, solicitudes a Graph, usuarios, dominios, roles, semáforo de MFA, lectura/eliminación de métodos |
| `Modules/Provisioning.psm1` | Configuración de FIDO2, tarjetas TOTP, MFA ficticia, TAP y cuentas de emergencia |
| `Modules/TenantReport.psm1` | Informe MFA: usuarios, roles, consultas de métodos agrupadas, valoración en semáforo, exportación a Excel |
| `Modules/Xlsx.psm1` | Escritor ligero de Excel (.xlsx sin Excel ni módulos adicionales) |
| `Modules/MfaGuideMail.psm1` | Guía de MFA: correo en el idioma del usuario, envío mediante Graph, fecha de envío en el objeto de usuario |
| `Modules/Localization.psm1` | Multilingüismo: carga los archivos de idioma y proporciona los textos |
| `Languages/*.json` | Textos por idioma (`en.json` es la referencia) |
| `Mail/Images/` | Capturas anonimizadas para el correo |
| `Install-Prerequisites.ps1` | Instalación previa opcional de todos los módulos |
| `docs/` | Documentación traducida y capturas de pantalla |
| `Logs/` | Archivos de registro diarios (se crean automáticamente, no se guardan en Git) |

---

## Añadir un idioma

1. Copie `Languages/en.json` y nómbrelo con el código del idioma, p. ej. `sv.json` para sueco.
2. Establezca `"_language"` con el nombre del idioma en ese idioma (p. ej. `"Svenska"`) y traduzca todos los textos. Los marcadores como `{0}` deben mantenerse.
3. Reinicie la herramienta: el idioma aparece automáticamente en la selección. Los textos que falten se muestran en inglés.
4. Opcional: añada una documentación traducida como `docs/README.<código>.md` y enlácela en la barra de idiomas de todos los archivos README.
