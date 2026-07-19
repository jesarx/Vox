# Voz encarnada — mezcladora corporal

Mezcladora de 4 canales escrita en [SuperCollider](https://supercollider.github.io/),
pensada para performance con micrófonos de contacto e hidrófonos sobre el
cuerpo (boca, garganta) más un micrófono de voz. Todo vive en un solo
archivo: [`mezcladora.scd`](mezcladora.scd).

## Requisitos

- SuperCollider 3.12 o superior (probado en Arch Linux con PipeWire).
- Una interfaz de audio con al menos 4 entradas. El patch está pensado
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
| EXTRA | 4 | libre (renómbralo en la configuración) | según la fuente |

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
        → [pitch shifter] → [ring modulator] → [fader / mute / pan]
        → suma estéreo → [master + limitador] → Main Out
              └─ envíos post-fader (REV / DLY) → [reverb / delay] → suma
```

El **limitador del master** está siempre activo, a propósito: con un
hidrófono en la boca frente a bocinas, un feedback inesperado puede
alcanzar niveles peligrosos para oídos y monitores. Su techo es ajustable
con la perilla **LIM** del strip MASTER (-12 a 0 dBFS, por defecto -0.4):
bajarlo lo convierte en un efecto audible que aplasta la mezcla.

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

### RING MOD

Ring modulator clásico: multiplica la señal por una senoidal, dejando las
sumas y restas de cada parcial con la portadora (voz metálica, de campana,
"dalek"). **FREC** fija la portadora — grave (30–100 Hz) suena a trémolo
áspero, media/aguda a campana inarmónica — y **MEZCLA** dosifica el
balance con la señal limpia.

### Envíos REV / DLY

Junto al fader de cada canal hay dos perillas de **envío post-fader**:
cuánto de ese canal entra a la **reverb** y al **delay** globales de la
columna FX. Son efectos de envío (una sola instancia de cada uno,
compartida): así dosificas cuánta reverberancia o eco lleva *cada*
micrófono sin ensuciar toda la mezcla ni triplicar el costo de CPU.

### Fader, medidor, mute/solo, reset
- Fader en dB (-60 a +6) con medidor RMS + pico post-fader.
- **M** silencia el canal; **S** silencia a todos los demás (los solos se
  combinan entre canales).
- **RESET** regresa todas las perillas del canal a sus valores por defecto
  (HPF encendido; distorsión, compresor, pitch y ring mod apagados). *No* toca el
  fader ni mute/solo: en vivo, un salto de volumen es peligroso.

### Entrada manual de valores

**Doble click** sobre cualquier perilla o fader (incluido el master) abre
una ventanita para teclear el valor exacto. Se escribe en las unidades que
muestra la etiqueta: Hz (acepta `2k` = 2000), ms para los tiempos del
compresor, dB, etc. Enter aplica, Esc cancela.

## Strip FX (reverb y delay)

El strip **FX** vive apilado **arriba del strip MASTER**, en la última
columna, con los dos efectos globales de envío y sus botones de
encendido:

- **REVERB** (`FreeVerb2`): **TAMAÑO** (dimensión del cuarto), **DAMP**
  (amortiguación de agudos en las reflexiones) y **RET** (nivel de retorno
  a la mezcla, en dB).
- **DELAY** (con retroalimentación filtrada): **TIEMPO** entre
  repeticiones (moverlo con el delay sonando "estira" el audio, como una
  cinta), **FB** (cuánto de cada eco vuelve a entrar), **FILTRO**
  (pasa-bajos dentro del lazo: cada eco se oscurece) y **RET**.
- **TAP**: marca el pulso a toques — dos o más toques seguidos fijan el
  TIEMPO del delay al intervalo entre ellos (20 ms a 2 s). Más de 2.5 s
  sin tocar reinicia la cuenta.
- **RESET**: regresa los efectos globales a sus valores por defecto
  (reverb y delay encendidos, limitador a -0.4 dBFS). No toca los envíos
  de los canales.

Los retornos entran a la mezcla **antes** del fader master y del
limitador. Todo (perillas y botones de encendido) se guarda en los presets
y es mapeable por MIDI con destinos `[\fx, \clave]`. Nota: la grabación
por stems captura las señales **sin** los retornos de FX; la grabación de
mezcla estéreo sí los incluye.

## Strip del MASTER

- **Osciloscopio**: forma de onda de la salida, **en vivo**, post-limitador
  (verde = izquierda, azul = derecha). Lo que ves es lo que sale por las
  bocinas.
- Fader general + medidores L/R + **MUTE** general.
- **LIM**: techo del limitador de seguridad (siempre activo; ver arriba).
  Registrado como perilla global: entra a los presets y se mapea por MIDI
  con `[\fx, \limTecho]`.
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
estéreo se graba **un WAV separado por canal**
(`sesion_..._boca.wav`, `sesion_..._garganta.wav`, `sesion_..._voz.wav`,
`sesion_..._extra.wav`).
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
que abras con **ABRIR…**. Tiene su propia perilla de volumen y siempre
pasa por el limitador del master.

- **Forma de onda**: al cargar un archivo se dibuja su forma de onda con
  una **línea de posición en vivo**. Click en cualquier punto = saltar ahí
  (funciona también mientras suena).
- **LOOP**: repite el archivo sin cortes; se puede prender y apagar
  durante la reproducción. Si saltaste a un punto con click, el loop
  regresa a ese punto.
- **Destino** (menú `→ MASTER / → BOCA / → GARGANTA / → VOZ`): con
  `→ MASTER` el audio va directo a la salida, sin procesar. Eligiendo un
  canal, el audio **entra a la cadena completa de ese canal** — EQ,
  distorsión, compresor, pitch, fader y envíos de reverb/delay — igual
  que si viniera del micrófono (se suman, si el micrófono está activo).
  Es la manera de **probar los efectos con un audio grabado**: carga una
  sesión, actívale LOOP, mándala a un canal y mueve perillas. Se puede
  cambiar de destino sin detener la reproducción.

## Presets

### Presets rápidos (slots)

La fila **PRESETS RÁPIDOS** tiene 4 slots pensados para el vivo: **un
click carga el slot completo al instante** (todas las perillas,
procesadores y faders), sin diálogos de archivos. También se cargan con
los botones de la **fila baja del X-Touch Mini** (notas 16–19).

Para guardar: presiona **[GUARDAR EN…]** (queda armado en rojo) y luego el
slot destino — el estado actual completo se guarda ahí. Los botones
muestran su estado: apagado = vacío, claro = ocupado, acento = el último
cargado/guardado. En el controlador, los LEDs de la fila baja se encienden
en los slots ocupados.

### Presets de archivo

**GUARDAR PRESET** serializa el estado completo de la mezcladora (todas las
perillas, qué procesadores están encendidos y los faders) **junto con los
presets rápidos de la sesión** a un archivo binario; **CARGAR PRESET**
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
| **CONCIERTO** *(activo al arrancar)* | drive de los 4 canales, campana media (MID g) de los 4 canales | master |
| **MEZCLA** | faders de los 4 canales, trims de los 4 canales | master |
| **BOCA** | trim, HPF, LO g, MID g, HI g, drive, mezcla dist, fader del canal | master |
| **GARGANTA** | igual que BOCA, para el canal 2 | master |
| **VOZ** | trim, HPF, MID g, drive, pitch, dispersión, mezcla pitch, fader del canal | master |
| **EXTRA** | igual que BOCA, para el canal 4 | master |

Notas fijas (independientes del mapa activo):

| Nota | Acción |
|---|---|
| 8 | ciclar al siguiente mapa |
| 9, 10, 11, 12 | toggle de mute de los canales 1–4 |
| 15 | toggle de grabación (REC/STOP) |
| 16–19 | cargar el preset rápido 1–4 (fila baja del X-Touch Mini) |

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

```supercollider
[\fx, \clave]               // una perilla de la columna FX (reverb/delay)
```

Las claves de perilla disponibles están listadas ahí mismo en un
comentario (`\trim`, `\hpfFreq`, `\drive`, `\pitchRatio`, `\ringFreq`,
`\sendRev`, `\revTamano`, `\delTiempo`, `\limTecho`, …). Puedes agregar tantos mapas como quieras;
el botón los cicla en orden.

## Configuración

Todo lo configurable vive al **inicio del archivo** (sección 0, `~cfg`):

- `titulo` — nombre de la app (barra de la ventana y encabezado).
- `canales` — nombre y entrada física de cada canal (agregar un canal
  aquí crea su strip completo automáticamente).
- `entradasHW` / `salidasHW` — canales que expone el servidor de audio.
- `carpetaRec`, `formatoRec`, `bitsRec` — dónde y cómo se graba.
- `ventanaX/Y/Ancho/Alto` — geometría de la ventana.
- `anchoColFader`, `anchoFader`, `anchoMedidor` — ancho de la columna del
  fader de cada strip (mute/solo, envíos, fader, medidor, reset) y de sus
  controles. La columna es de ancho fijo: el espacio sobrante del strip se
  va al lado del EQ.
- `midiHabilitado`, `notaCambiarMapa`, `notasMute`, `notaRec`,
  `notasSlots` — notas MIDI (la cantidad de slots rápidos la define el
  tamaño de `notasSlots`).
- `midiNombreControlador`, `midiCanalLeds` — retroalimentación de LEDs.
- `sampleRate`, `blockSize`, `hardwareBufferSize` — audio/latencia (ver
  la sección siguiente).
- `~mapasMIDI` — los bancos de mapeo descritos arriba.

## Latencia

La latencia de ida y vuelta (micrófono → proceso → bocinas) depende sobre
todo del **tamaño de buffer de hardware** y el **sample rate**:
`latencia ≈ 2 × buffer / sampleRate` (p. ej. 2 × 256 / 48000 ≈ 10.7 ms;
con 128 ≈ 5.3 ms). Para el gesto vocal en vivo, por debajo de ~10 ms se
siente inmediato.

### Desde el patch

En la sección 0 están `sampleRate`, `blockSize` y `hardwareBufferSize`
(por defecto en `nil` = respetar el sistema). **Bajo PipeWire estos
valores casi siempre son ignorados**: scsynth corre como cliente JACK y
quien fija el buffer real es el *quantum* de PipeWire — configúralo desde
el sistema (abajo). En otras configuraciones (JACK puro, otra máquina) sí
aplican.

### Desde el sistema (PipeWire — recomendado)

Fija el quantum antes de abrir SuperCollider, o en caliente:

```bash
# opción A: fijar el quantum globalmente en caliente (48000 Hz, 128 muestras)
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 128

# revisar qué quantum está usando cada cliente:
pw-top

# regresar al automático:
pw-metadata -n settings 0 clock.force-quantum 0
```

```bash
# opción B: solo para SuperCollider, al lanzarlo:
PIPEWIRE_LATENCY=128/48000 scide
```

Baja de 256 → 128 → 64 hasta que aparezcan clicks/dropouts (xruns) y
quédate un paso arriba. Con la UMC404HD, 128/48000 suele ser estable.

### Otras fuentes de latencia

- El **pitch shifter** granular añade ~150 ms *cuando está encendido*
  (el tamaño de su ventana de granos; es inherente al método). Si lo
  quieres más inmediato a costa de más artefactos, baja `windowSize` en
  el SynthDef `\ins_pitch` (p. ej. a `0.08`).
- El resto de la cadena (EQ, distorsión, compresor, envíos) trabaja
  muestra a muestra o por bloque: no añade latencia perceptible.
- La UMC404HD tiene **monitoreo directo** por hardware (perilla
  Direct Monitor): útil como referencia de latencia cero de la señal
  seca, aunque en este proyecto lo que importa es la señal procesada.

## Extender la cadena de efectos

El patrón para agregar un efecto nuevo está documentado al final de
`mezcladora.scd`: un `SynthDef` que lee su bus con `In.ar` y lo
sobreescribe con `ReplaceOut.ar`, instanciado con `Synth.tail` en el grupo
del canal. Registrando sus perillas en `~reg`, el RESET, los presets y los
mapas MIDI lo incluyen automáticamente.
