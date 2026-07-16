# Voz encarnada — mezcladora corporal

Mezcladora de 3 canales escrita en [SuperCollider](https://supercollider.github.io/),
pensada para performance con micrófonos de contacto e hidrófonos sobre el
cuerpo (boca, garganta) más un micrófono de voz. Todo vive en un solo
archivo: [`mezcladora.scd`](mezcladora.scd).

## Requisitos

- SuperCollider 3.12 o superior (probado en Arch Linux con PipeWire).
- Una interfaz de audio con al menos 3 entradas. El patch está pensado
  para la **Behringer UMC404HD**, pero cualquier interfaz sirve ajustando
  la configuración.
- Opcional: un controlador MIDI. Los mapas incluidos están pensados para
  el **Behringer X-Touch Mini**, pero son completamente configurables.

## Mapa de canales (por defecto)

| Canal | Entrada física | Fuente | Switch de la UMC404HD |
|---|---|---|---|
| BOCA | 1 | hidrófono JrF | Instrument / Hi-Z |
| GARGANTA | 2 | micrófono de contacto JrF | Instrument / Hi-Z |
| VOZ | 3 | Shure SM57 | Mic |

## Uso

1. Abre `mezcladora.scd` en el IDE de SuperCollider.
2. Colócate dentro del bloque grande entre paréntesis y evalúa con
   **Ctrl+Enter**. El servidor arranca solo y aparece la ventana.
3. Si algo se traba: **Ctrl+.** (detiene todo), cierra la ventana y vuelve
   a evaluar el bloque.

Al cerrar la ventana se liberan todos los nodos, buses, OSCdefs y MIDIdefs
del patch (y se detiene la grabación si estaba corriendo).

## Flujo de señal

Cada canal es una cadena de "inserts" sobre un bus mono privado; el orden
de los nodos en el servidor es el orden de procesamiento:

```
SoundIn → [trim] → [HPF + EQ 3 bandas] → [distorsión] → [compresor]
        → [pitch shifter] → [fader / mute / pan] → suma estéreo
        → [master + limitador] → Main Out
```

El **limitador del master** (techo ~-0.4 dBFS) está siempre activo, a
propósito: con un hidrófono en la boca frente a bocinas, un feedback
inesperado puede alcanzar niveles peligrosos para oídos y monitores.

## Secciones de cada canal

### Curva de EQ
Arriba de las perillas de EQ, cada canal dibuja la **curva de respuesta en
frecuencia** resultante de sus ajustes (HPF + 3 bandas). No analiza el
audio en vivo: se calcula analíticamente a partir de las perillas y se
redibuja cada vez que giras una. Eje X logarítmico de 20 Hz a 20 kHz
(rejilla en 100 Hz, 1 kHz y 10 kHz), eje Y de ±24 dB (rejilla en 0 y ±12 dB).

### TRIM / PAN / EQ
- **TRIM**: ganancia digital de entrada (±24 dB), antes de todo.
- **PAN**: posición en el campo estéreo.
- **HPF**: pasa-altos de 12 dB/oct con botón de encendido. Esencial en los
  piezos contra el retumbe subgrave de manejo y cables.
- **LO f / LO g**: shelf grave (frecuencia y ganancia).
- **MID f / MID g / MID Q**: campana media paramétrica.
- **HI f / HI g**: shelf agudo.

### DISTORSIÓN
Saturación `tanh` con mezcla seco/húmedo. **DRIVE** controla la cantidad de
saturación; **MEZCLA** en valores medios da *distorsión paralela*: se
conserva el cuerpo limpio de la señal y la saturación se suma como textura.

### COMPRESOR
Compresor clásico (la señal se controla a sí misma): **THR** (umbral),
**RATIO**, **ATK** (ataque), **REL** (relajación) y **MAKEUP** (ganancia de
compensación).

### PITCH
Pitch shifter **granular** (`PitchShift`): transpone sin cambiar la duración.
- **PITCH**: 0.5x = una octava abajo, 1x = sin cambio, 2x = una octava arriba.
- **DISP**: dispersión de los granos en afinación y tiempo; en valores
  altos deshace la señal en textura granular pura.
- **MEZCLA**: balance entre la señal original y la transpuesta.

### Fader, medidor, mute/solo, reset
- Fader en dB (-60 a +6) con medidor RMS + pico post-fader.
- **M** silencia el canal; **S** silencia a todos los demás (los solos se
  combinan entre canales).
- **RESET** regresa todas las perillas del canal a sus valores por defecto
  (HPF encendido; distorsión, compresor y pitch apagados). *No* toca el
  fader ni mute/solo: en vivo, un salto de volumen es peligroso.

### Entrada manual de valores

**Doble click** sobre cualquier perilla o fader (incluido el master) abre
una ventanita para teclear el valor exacto. Se escribe en las unidades que
muestra la etiqueta: Hz (acepta `2k` = 2000), ms para los tiempos del
compresor, dB, etc. Enter aplica, Esc cancela.

## Strip del MASTER

- **Osciloscopio**: forma de onda de la salida, **en vivo**, post-limitador
  (verde = izquierda, azul = derecha). Lo que ves es lo que sale por las
  bocinas.
- Fader general + medidores L/R + **MUTE** general.
- **● REC / ■ STOP** con checkbox **stems**: graba la mezcla estéreo tal
  como la escuchas, o — con el checkbox encendido — un WAV separado por
  canal (ver abajo).
- **GUARDAR / CARGAR PRESET** (ver abajo).

## Grabaciones

Se guardan como **WAV de 24 bits** en la subcarpeta **`rec/`** junto al
archivo `.scd` (la carpeta se crea sola y está en el `.gitignore`, así que
las sesiones no se suben al repositorio). El nombre incluye fecha y hora:
`sesion_AAMMDD_HHMMSS.wav`. Al detener la grabación, el archivo se carga
automáticamente en el reproductor.

### Grabación por stems

Con el checkbox **stems** (junto a REC) encendido, en lugar de la mezcla
estéreo se graban **3 WAVs separados, uno por canal**
(`sesion_..._boca.wav`, `sesion_..._garganta.wav`, `sesion_..._voz.wav`).
La señal de cada stem es **post-fader y pre-pan** (mono, con todos los
efectos del canal y el nivel del fader aplicados): lo que ese canal aportó
a la mezcla, listo para re-mezclar en un DAW. El modo se elige antes de
arrancar la grabación y no puede cambiarse a media sesión.

> Nota: SuperCollider solo conoce la ubicación del `.scd` si el documento
> está guardado en disco. Si evalúas el código desde un documento sin
> guardar, las grabaciones caen a `~/rec/` y se avisa en la post window.

## Reproductor

La fila inferior reproduce cualquier archivo de audio por streaming desde
disco (sin cargarlo a RAM): la última grabación de sesión o cualquier WAV
que abras con **ABRIR…**. Tiene su propia perilla de volumen y pasa por el
limitador del master, no por los canales.

## Presets

### Presets rápidos (slots)

La fila **PRESETS RÁPIDOS** tiene 8 slots pensados para el vivo: **un
click carga el slot completo al instante** (todas las perillas,
procesadores y faders), sin diálogos de archivos. También se cargan con
los botones de la **fila baja del X-Touch Mini** (notas 16–23).

Para guardar: presiona **[GUARDAR EN…]** (queda armado en rojo) y luego el
slot destino — el estado actual completo se guarda ahí. Los botones
muestran su estado: apagado = vacío, claro = ocupado, acento = el último
cargado/guardado. En el controlador, los LEDs de la fila baja se encienden
en los slots ocupados.

### Presets de archivo

**GUARDAR PRESET** serializa el estado completo de la mezcladora (todas las
perillas, qué procesadores están encendidos y los faders) **junto con los
8 presets rápidos de la sesión** a un archivo binario; **CARGAR PRESET**
restaura todo, slots incluidos. Esencial para performance: llegas, cargas
tu preset, y tanto la mezcladora como tus presets rápidos quedan como en
el ensayo.

## MIDI: mapas por bancos

El patch incluye un sistema de mapeos MIDI **por bancos**: varios mapas
definidos en la configuración, de los cuales solo uno está activo a la vez.
Se cambia de mapa con el botón **MAPA →** de la GUI o con una nota MIDI
(un botón del controlador). El mapa activo se muestra en el encabezado.

Todo lo que llega por MIDI se aplica sobre los mismos controles de la GUI
(`valueAction`), así que perilla en pantalla, curva de EQ, synth y presets
quedan siempre sincronizados, muevas lo que muevas.

### Mapas incluidos (pensados para el X-Touch Mini, capa A)

En modo estándar, el X-Touch Mini manda: encoders → CC 1–8, fader → CC 9,
push de los encoders → notas 0–7, fila alta de botones → notas 8–15, fila
baja → notas 16–23.

| Mapa | Encoders 1–8 | CC 9 (fader) |
|---|---|---|
| **CONCIERTO** *(activo al arrancar)* | drive de los 3 canales, campana media (MID g) de los 3 canales, pitch y mezcla de pitch de la voz | master |
| **MEZCLA** | faders de los 3 canales, master, trims de los 3 canales, pan de la voz | master |
| **BOCA** | trim, HPF, LO g, MID g, HI g, drive, mezcla dist, fader del canal | master |
| **GARGANTA** | igual que BOCA, para el canal 2 | master |
| **VOZ** | trim, HPF, MID g, drive, pitch, dispersión, mezcla pitch, fader del canal | master |

Notas fijas (independientes del mapa activo):

| Nota | Acción |
|---|---|
| 8 | ciclar al siguiente mapa |
| 9, 10, 11 | toggle de mute de los canales 1, 2, 3 |
| 15 | toggle de grabación (REC/STOP) |
| 16–23 | cargar el preset rápido 1–8 (fila baja del X-Touch Mini) |

### LEDs del controlador

SC manda MIDI **de regreso** al controlador (se busca por nombre el
dispositivo configurado en `midiNombreControlador`, por defecto
`"X-TOUCH MINI"`):

- Los **anillos de los encoders** se actualizan con los valores de los
  destinos del mapa activo — al cambiar de banco, al cargar un preset o un
  slot, los anillos saltan a las posiciones reales de ese mapa.
- Los **botones de mute** se encienden cuando el canal está muteado, el de
  **REC** mientras se graba, y los de la **fila baja** en los slots
  ocupados. Al cerrar la mezcladora se apagan todos.

Si el controlador no está conectado, todo funciona igual pero sin LEDs.

### Personalizar los mapas

Todo está en la **sección 0** de `mezcladora.scd` (`~mapasMIDI` y las
claves `nota*` de `~cfg`). Cada entrada de un mapa asigna un número de CC
a un destino:

```supercollider
[\perilla, canal, \clave]   // una perilla del canal 0, 1 o 2
[\fader, canal]             // el fader de ese canal
[\master]                   // el fader master
```

Las claves de perilla disponibles están listadas ahí mismo en un
comentario (`\trim`, `\hpfFreq`, `\drive`, `\pitchRatio`, …). Puedes
agregar tantos mapas como quieras; el botón los cicla en orden.

## Configuración

Todo lo configurable vive al **inicio del archivo** (sección 0, `~cfg`):

- `titulo` — nombre de la app (barra de la ventana y encabezado).
- `canales` — nombre y entrada física de cada canal (agregar un canal
  aquí crea su strip completo automáticamente).
- `entradasHW` / `salidasHW` — canales que expone el servidor de audio.
- `carpetaRec`, `formatoRec`, `bitsRec` — dónde y cómo se graba.
- `ventanaX/Y/Ancho/Alto` — geometría de la ventana.
- `midiHabilitado`, `notaCambiarMapa`, `notasMute`, `notaRec`,
  `notasSlots` — notas MIDI (la cantidad de slots rápidos la define el
  tamaño de `notasSlots`).
- `midiNombreControlador`, `midiCanalLeds` — retroalimentación de LEDs.
- `~mapasMIDI` — los bancos de mapeo descritos arriba.

## Extender la cadena de efectos

El patrón para agregar un efecto nuevo está documentado al final de
`mezcladora.scd`: un `SynthDef` que lee su bus con `In.ar` y lo
sobreescribe con `ReplaceOut.ar`, instanciado con `Synth.tail` en el grupo
del canal. Registrando sus perillas en `~reg`, el RESET, los presets y los
mapas MIDI lo incluyen automáticamente.
