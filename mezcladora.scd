/*
================================================================================
  VOZ ENCARNADA — Mezcladora corporal · v6
  Patch de SuperCollider para Behringer UMC404HD · Arch Linux / PipeWire
================================================================================

  NOVEDADES DE ESTA VERSIÓN
  -------------------------
  · 4 CANALES: se usa también la entrada 4 de la UMC404HD (canal EXTRA,
    renómbralo en la sección 0 según lo que conectes).
  · TAP en el delay: marca el pulso a toques y el TIEMPO se fija solo.
  · Botón RESET en la columna FX (regresa reverb y delay a sus defaults).
  · 4 presets rápidos (antes 8): los que caben en media fila del X-Touch.
  · La columna del fader (mute/solo, envíos, fader, medidor, reset) tiene
    ancho FIJO — el espacio sobrante del strip se va al lado del EQ.
    Ajustable en la sección 0: anchoColFader / anchoFader / anchoMedidor.

  VERSIONES ANTERIORES: reverb/delay por envíos · player con loop, ruteo
  a canal y forma de onda · latencia configurable · presets rápidos por
  slots · LEDs del X-Touch Mini · mapa CONCIERTO · grabación por stems ·
  doble click para teclear valores · curva de EQ por canal · pitch shifter
  granular · osciloscopio del master · mapas MIDI por bancos · grabación
  en ./rec/ · sección 0 de configuración.

  MAPA DE CANALES (configurable en la sección 0):
    Entrada 1 → BOCA      (hidrófono JrF)        [switch: Instrument/Hi-Z]
    Entrada 2 → GARGANTA  (contacto JrF)         [switch: Instrument/Hi-Z]
    Entrada 3 → VOZ       (SM57)                 [switch: Mic]
    Entrada 4 → EXTRA     (lo que conectes)      [switch: según la fuente]

  FLUJO DE SEÑAL POR CANAL:
  -------------------------
    SoundIn → [trim] → [HPF + EQ 3 bandas] → [distorsión] → [compresor]
            → [pitch shifter] → [fader/mute/pan] → suma estéreo
            → [master + limitador] → Main Out
                └─ envíos post-fader → [reverb / delay] → suma estéreo

    ¿Por qué la distorsión ANTES del compresor? Porque la saturación genera
    picos y armónicos nuevos; el compresor al final doma la dinámica de TODO
    lo que pasó antes. El pitch shifter va al final de la cadena de inserts
    para transponer la señal ya procesada. Si quieres otro orden, invierte
    el orden de creación de los synths en la sección 4 — el orden de los
    nodos dentro del grupo del canal ES el orden de procesamiento.

  GRABACIONES: WAV 24-bit en ./rec/ (carpeta ignorada por git).
  PRESETS:     los guardas donde quieras con el diálogo de archivos.

  USO: evalúa el bloque grande (colócate dentro y Ctrl+Enter).
       Si presionas Ctrl+. cierra la ventana y vuelve a evaluar todo.
================================================================================
*/

(
// ═══════════════════════════════════════════════════════════════════════════
// 0. CONFIGURACIÓN — edita aquí, no en el resto del código
// ═══════════════════════════════════════════════════════════════════════════

~cfg = (
	// Título de la app (barra de la ventana y encabezado de la GUI).
	titulo: "Voz encarnada",

	// Canales: nombre que se muestra y entrada física de la interfaz
	// (0 = entrada 1 de la UMC404HD, 1 = entrada 2, etc.).
	canales: [
		(nombre: "BOCA\nhidrófono", entrada: 0),
		(nombre: "GARGANTA\ncontacto", entrada: 1),
		(nombre: "VOZ\nSM57", entrada: 2),
		(nombre: "EXTRA\nentrada 4", entrada: 3)   // renómbralo a tu gusto
	],

	// Entradas/salidas que expone el servidor de audio.
	entradasHW: 4,     // la UMC404HD expone 4
	salidasHW: 2,      // Main Out estéreo

	// Grabación: subcarpeta (relativa a este archivo .scd) y formato.
	carpetaRec: "rec",
	formatoRec: "wav",
	bitsRec: "int24",

	// Ventana: posición y tamaño inicial.
	ventanaX: 40, ventanaY: 40,
	ventanaAncho: 1120, ventanaAlto: 970,

	// Geometría de la columna del fader (la parte derecha de cada strip:
	// mute/solo, envíos REV/DLY, fader, medidor y reset). El ancho de la
	// columna está FIJO: el espacio sobrante del strip se va al lado del
	// EQ, no a esta columna. Ajusta fino aquí:
	anchoColFader: 78,   // ancho total de la columna (px)
	anchoFader: 34,      // ancho del fader
	anchoMedidor: 12,    // ancho del medidor de nivel

	// ── Audio / latencia ────────────────────────────────────────────────
	// nil = respeta lo que tenga el sistema. Bajo PipeWire/JACK, quien
	// manda es el "quantum" de PipeWire (ver la sección de latencia del
	// README): estos valores solo aplican donde el servidor pueda pedirlos.
	sampleRate: nil,           // p. ej. 48000
	blockSize: 64,             // bloque interno de scsynth (potencia de 2)
	hardwareBufferSize: nil,   // p. ej. 256 o 128 para menos latencia

	// ── MIDI ────────────────────────────────────────────────────────────
	// Pensado para el Behringer X-Touch Mini en modo estándar (capa A):
	//   · encoders          → CC 1..8
	//   · fader             → CC 9
	//   · push de encoders  → notas 0..7
	//   · botones fila alta → notas 8..15
	//   · botones fila baja → notas 16..23
	// Cualquier otro controlador sirve: cambia los números de CC/nota.
	midiHabilitado: true,
	notaCambiarMapa: 8,          // botón que cicla entre los mapas de abajo
	notasMute: [9, 10, 11, 12],  // toggle de mute de los canales 1-4
	notaRec: 15,                 // toggle de grabación (REC/STOP)
	notasSlots: [16, 17, 18, 19],   // fila baja (mitad izq.) → presets rápidos

	// LEDs del controlador: SC manda MIDI de regreso al dispositivo cuyo
	// nombre contenga este texto (anillos de encoders + botones). El canal
	// 10 (= canal 11 contando desde 1) es el del X-Touch Mini en modo
	// estándar. Si el dispositivo no aparece, los LEDs se omiten sin error.
	midiNombreControlador: "X-TOUCH MINI",
	midiCanalLeds: 10
);

// ── Mapas MIDI ──────────────────────────────────────────────────────────────
// Cada mapa asigna números de CC a destinos. Presiona el botón de cambio de
// mapa (GUI o nota MIDI) para ciclar entre ellos. Formatos de destino:
//   [\perilla, canal, \clave]  → una perilla registrada del canal (0,1,2)
//   [\fader, canal]            → el fader de ese canal
//   [\master]                  → el fader master
//   [\fx, \clave]              → una perilla de la columna FX (reverb/delay)
// Claves de perilla disponibles por canal:
//   \trim \pan \hpfFreq \loFreq \loGain \midFreq \midGain \midQ \hiFreq
//   \hiGain \drive \mezcla \umbral \ratio \atk \rel \makeup
//   \pitchRatio \pitchDisp \pitchMezcla \sendRev \sendDel
// Claves de la columna FX:
//   \revTamano \revDamp \revRetorno \delTiempo \delFb \delFiltro \delRetorno
~mapasMIDI = [
	(
		// El mapa de arranque: lo más útil en un concierto, de los cuatro
		// micrófonos a la vez — saturación y campana media de cada canal.
		// (El pitch de la voz vive en el mapa VOZ, a dos toques del botón.)
		nombre: "CONCIERTO",
		ccs: Dictionary.newFrom([
			1, [\perilla, 0, \drive],     // encoders 1-4 → drive de cada canal
			2, [\perilla, 1, \drive],
			3, [\perilla, 2, \drive],
			4, [\perilla, 3, \drive],
			5, [\perilla, 0, \midGain],   // encoders 5-8 → campana media
			6, [\perilla, 1, \midGain],
			7, [\perilla, 2, \midGain],
			8, [\perilla, 3, \midGain],
			9, [\master]                  // fader físico → master
		])
	),
	(
		nombre: "MEZCLA",
		ccs: Dictionary.newFrom([
			1, [\fader, 0],           // encoders 1-4 → faders de los canales
			2, [\fader, 1],
			3, [\fader, 2],
			4, [\fader, 3],
			5, [\perilla, 0, \trim],  // encoders 5-8 → trims
			6, [\perilla, 1, \trim],
			7, [\perilla, 2, \trim],
			8, [\perilla, 3, \trim],
			9, [\master]              // fader físico → master
		])
	),
	(
		nombre: "BOCA",
		ccs: Dictionary.newFrom([
			1, [\perilla, 0, \trim],
			2, [\perilla, 0, \hpfFreq],
			3, [\perilla, 0, \loGain],
			4, [\perilla, 0, \midGain],
			5, [\perilla, 0, \hiGain],
			6, [\perilla, 0, \drive],
			7, [\perilla, 0, \mezcla],
			8, [\fader, 0],
			9, [\master]
		])
	),
	(
		nombre: "GARGANTA",
		ccs: Dictionary.newFrom([
			1, [\perilla, 1, \trim],
			2, [\perilla, 1, \hpfFreq],
			3, [\perilla, 1, \loGain],
			4, [\perilla, 1, \midGain],
			5, [\perilla, 1, \hiGain],
			6, [\perilla, 1, \drive],
			7, [\perilla, 1, \mezcla],
			8, [\fader, 1],
			9, [\master]
		])
	),
	(
		nombre: "VOZ",
		ccs: Dictionary.newFrom([
			1, [\perilla, 2, \trim],
			2, [\perilla, 2, \hpfFreq],
			3, [\perilla, 2, \midGain],
			4, [\perilla, 2, \drive],
			5, [\perilla, 2, \pitchRatio],
			6, [\perilla, 2, \pitchDisp],
			7, [\perilla, 2, \pitchMezcla],
			8, [\fader, 2],
			9, [\master]
		])
	),
	(
		nombre: "EXTRA",
		ccs: Dictionary.newFrom([
			1, [\perilla, 3, \trim],
			2, [\perilla, 3, \hpfFreq],
			3, [\perilla, 3, \loGain],
			4, [\perilla, 3, \midGain],
			5, [\perilla, 3, \hiGain],
			6, [\perilla, 3, \drive],
			7, [\perilla, 3, \mezcla],
			8, [\fader, 3],
			9, [\master]
		])
	)
];

// Ruta de este archivo (se captura AHORA, mientras el intérprete todavía
// sabe qué documento está evaluando; dentro de waitForBoot ya sería nil).
~rutaScript = thisProcess.nowExecutingPath;

// ═══════════════════════════════════════════════════════════════════════════
// 1. CONFIGURACIÓN DEL SERVIDOR
// ═══════════════════════════════════════════════════════════════════════════
s.options.numInputBusChannels  = ~cfg[\entradasHW];
s.options.numOutputBusChannels = ~cfg[\salidasHW];
s.options.memSize = 2.pow(16);

// Latencia (ver sección 0 y README): solo se piden si están configurados.
~cfg[\sampleRate]         !? { |v| s.options.sampleRate = v };
~cfg[\blockSize]          !? { |v| s.options.blockSize = v };
~cfg[\hardwareBufferSize] !? { |v| s.options.hardwareBufferSize = v };

// Formato de grabación: WAV de 24 bits — portable a cualquier DAW/editor,
// ideal para el archivo de tus bitácoras de sesión.
s.recHeaderFormat = ~cfg[\formatoRec];
s.recSampleFormat = ~cfg[\bitsRec];

s.waitForBoot({

	// ───────────────────────────────────────────────────────────────────────
	// Variables locales (en SC, "var" siempre va al inicio del bloque)
	// ───────────────────────────────────────────────────────────────────────
	var numCanales, nombres, colFondo, colStrip, colStripMaster, colAcento,
	    colTexto, colTextoSuave, colRojo, colVerde, colAzul, colRejilla,
	    fuente, fuentePeq, fuenteTitulo, fuenteApp,
	    specTrim, specPan, specHPF, specLoF, specMidF, specMidQ, specHiF,
	    specGain, specFader, specDrive, specMezcla, specThr, specRatio,
	    specAtk, specRel, specMakeup, specVolPlayer, specPitch, specDisp,
	    specTiempoDel, specFb, specFiltroDel, specRetorno,
	    hazKnob, hazSeccion, hazStrip, stripFx, stripMaster, filaPlayer,
	    filaSlots, filaTitulo, btnMapa, ventana;

	numCanales = ~cfg[\canales].size;
	nombres    = ~cfg[\canales].collect { |c| c[\nombre] };

	// ═══════════════════════════════════════════════════════════════════════
	// 2. BUSES Y GRUPOS
	// ═══════════════════════════════════════════════════════════════════════
	// Un bus de audio mono privado por canal: la señal viaja por él entre
	// las etapas de su cadena (cada etapa lo lee y lo reemplaza).
	~busCanal = numCanales.collect { Bus.audio(s, 1) };

	// Bus mono paralelo por canal: la salida de canal escribe ahí una copia
	// post-fader de su señal. De estos "taps" lee la grabación por stems.
	~busGrab = numCanales.collect { Bus.audio(s, 1) };

	// Buses de ENVÍO para los efectos globales: cada canal suma ahí su
	// señal post-fader multiplicada por su perilla de envío (REV / DLY);
	// una sola reverb y un solo delay leen la suma y regresan en estéreo.
	~busRev = Bus.audio(s, 1);
	~busDel = Bus.audio(s, 1);

	// El orden de creación de los grupos define el orden de ejecución del
	// audio. Un synth solo puede leer lo que otro escribió si corre DESPUÉS.
	~gEntradas = Group.new(s);              // 1º lectura de micrófonos
	~gFx       = Group.after(~gEntradas);   // 2º procesamiento por canal
	~gSalidas  = Group.after(~gFx);         // 3º faders → suma estéreo
	~gPlayer   = Group.after(~gSalidas);    // 4º reproductor (también pasa
	                                        //    por el limitador del master)
	~gMaster   = Group.after(~gPlayer);     // 5º master + limitador + scope

	// Subgrupo de FX por canal: la cadena de inserts de ese canal vive aquí.
	~gFxCanal = numCanales.collect { Group.tail(~gFx) };

	// Grupo para la grabación por stems: se inserta justo después de las
	// salidas de canal, donde los taps ya tienen la señal post-fader.
	~gGrab = Group.after(~gSalidas);

	// Grupo de los efectos globales (reverb/delay): después de los envíos
	// de canal y antes del master, para que sus retornos pasen también por
	// el fader general y el limitador.
	~gFxGlobal = Group.after(~gGrab);

	// Buffer especial para el osciloscopio de salida (memoria compartida
	// entre servidor y GUI: por eso la forma de onda puede verse en vivo).
	~scopeBuf = ScopeBuffer.alloc(s);

	// ═══════════════════════════════════════════════════════════════════════
	// 3. SYNTHDEFS
	// ═══════════════════════════════════════════════════════════════════════
	// Todos los efectos "insert" siguen el mismo patrón:
	//   In.ar(bus) → procesar → ReplaceOut.ar(bus)
	// y todos tienen un parámetro \on para activarse/desactivarse (bypass).

	// ── 3a. ENTRADA: lee el micrófono físico y aplica el trim ──────────────
	SynthDef(\ent_entrada, { |bus = 0, canalIn = 0, trim = 0|
		var sig;
		// El mapa de buses del servidor es: [salidas 0..1][entradas 2..5][privados 6...]
		// In.ar(NumOutputBuses.ir + n) lee la entrada física n (= SoundIn.ar(n)).
		sig = In.ar(NumOutputBuses.ir + canalIn, 1);
		// .dbamp convierte decibeles → amplitud; .lag suaviza (evita clicks).
		sig = sig * trim.dbamp.lag(0.05);
		Out.ar(bus, sig);   // Out.ar SUMA al bus
	}).add;

	// ── 3b. ECUALIZADOR: HPF + low shelf + campana media + high shelf ──────
	SynthDef(\ent_eq, {
		|bus = 0,
		 hpfOn = 1, hpfFreq = 80,
		 loFreq = 180, loGain = 0,
		 midFreq = 800, midGain = 0, midQ = 1,
		 hiFreq = 5000, hiGain = 0|

		var sig, filtrada;
		sig = In.ar(bus, 1);

		// Pasa-altos 12 dB/oct. Clave para los piezos: quita el retumbe
		// subgrave de manejo, cables y conducción ósea indeseada.
		filtrada = HPF.ar(sig, hpfFreq.lag(0.1));
		// Select.ar elige por índice: 0 = sin filtrar, 1 = filtrada.
		sig = Select.ar(hpfOn, [sig, filtrada]);

		// Filtros BEQSuite (biquads estilo consola):
		sig = BLowShelf.ar(sig, loFreq.lag(0.1), 1.0, loGain.lag(0.05));
		// BPeakEQ usa rq (recíproco de Q): Q alto = campana angosta.
		sig = BPeakEQ.ar(sig, midFreq.lag(0.1), midQ.reciprocal.lag(0.1), midGain.lag(0.05));
		sig = BHiShelf.ar(sig, hiFreq.lag(0.1), 1.0, hiGain.lag(0.05));

		// ReplaceOut SOBREESCRIBE el bus (Out.ar sumaría → duplicaría señal).
		ReplaceOut.ar(bus, sig);
	}).add;

	// ── 3c. DISTORSIÓN: saturación tanh con mezcla seco/húmedo ─────────────
	SynthDef(\ins_dist, { |bus = 0, on = 0, drive = 4, mezcla = 0.5|
		var sig, d, dist, hum;
		sig = In.ar(bus, 1);
		d   = drive.lag(0.05);

		// tanh es una curva de saturación suave: comprime los picos y genera
		// armónicos impares (sonido "cálido/rasposo"). Dividir por sqrt(drive)
		// compensa parcialmente el aumento de volumen al subir el drive.
		dist = (sig * d).tanh / d.sqrt;

		// XFade2 mezcla dos señales; su posición va de -1 (solo A) a 1 (solo B).
		// Con mezcla < 1 obtienes "distorsión paralela": el cuerpo limpio de la
		// señal se conserva y la saturación se suma como textura — muy útil
		// para no perder el detalle fino de saliva/fricciones del hidrófono.
		hum = XFade2.ar(sig, dist, mezcla.lag(0.05) * 2 - 1);

		ReplaceOut.ar(bus, Select.ar(on, [sig, hum]));   // on=0 → bypass
	}).add;

	// ── 3d. COMPRESOR ────────────────────────────────────────────────────────
	SynthDef(\ins_comp, { |bus = 0, on = 0, umbral = -20, ratio = 4,
	                       atk = 0.005, rel = 0.1, makeup = 0|
		var sig, comp;
		sig = In.ar(bus, 1);

		// Compander: por encima del umbral, la ganancia crece con pendiente
		// 1/ratio (ratio 4 → de cada 4 dB que entran de más, salen 1).
		// La señal se usa a sí misma como control (compresión clásica).
		comp = Compander.ar(sig, sig,
			thresh:     umbral.dbamp.lag(0.05),   // el umbral llega en dB
			slopeBelow: 1,                        // debajo del umbral: intacto
			slopeAbove: ratio.reciprocal.lag(0.05),
			clampTime:  atk,                      // ataque
			relaxTime:  rel                       // relajación
		);
		// Ganancia de compensación: al comprimir bajas los picos; con makeup
		// recuperas nivel general → percepción de más "cuerpo" y sustain.
		comp = comp * makeup.dbamp.lag(0.05);

		ReplaceOut.ar(bus, Select.ar(on, [sig, comp]));
	}).add;

	// ── 3e. PITCH SHIFTER granular (antes era el "ejemplo para extender") ──
	// Transpone sin cambiar la duración. Con disp alta los granos se
	// desordenan y la señal se vuelve textura granular pura — muy pertinente
	// para deshacer la voz en materia.
	SynthDef(\ins_pitch, { |bus = 0, on = 0, ratio = 1, disp = 0, mezcla = 1|
		var sig, desplazada, hum;
		sig = In.ar(bus, 1);
		// PitchShift trabaja con granos superpuestos:
		//   ratio 0.5 = una octava abajo, 2.0 = una octava arriba
		//   pitchDispersion/timeDispersion desordenan los granos → textura
		desplazada = PitchShift.ar(sig,
			windowSize: 0.15,
			pitchRatio: ratio.lag(0.1),
			pitchDispersion: disp.lag(0.1),
			timeDispersion: disp.lag(0.1) * 0.1
		);
		hum = XFade2.ar(sig, desplazada, mezcla.lag(0.05) * 2 - 1);
		ReplaceOut.ar(bus, Select.ar(on, [sig, hum]));
	}).add;

	// ── 3f. SALIDA DE CANAL: fader, mute/solo, pan → suma al master ────────
	SynthDef(\ent_salidaCanal, { |bus = 0, out = 0, amp = 1, mute = 1, pan = 0,
	                              idMedidor = 0, busGrab = 0,
	                              busRev = 0, busDel = 0, sendRev = 0, sendDel = 0|
		var sig;
		sig = In.ar(bus, 1);
		sig = sig * amp.lag(0.05) * mute.lag(0.02);
		// Medición post-fader → el medidor muestra lo que entra a la mezcla.
		SendPeakRMS.ar(sig, 20, 3, '/medidorCanal', idMedidor);
		// Copia mono post-fader al tap de grabación (mono, antes del pan):
		// de aquí lee la grabación por stems. Los buses de audio se limpian
		// solos en cada bloque, así que no cuesta nada cuando no se graba.
		Out.ar(busGrab, sig);
		// Envíos post-fader a los efectos globales: la perilla REV/DLY del
		// canal decide cuánto de ESTE canal llega a la reverb / al delay.
		Out.ar(busRev, sig * sendRev.lag(0.05));
		Out.ar(busDel, sig * sendDel.lag(0.05));
		Out.ar(out, Pan2.ar(sig, pan.lag(0.05)));
	}).add;

	// ── 3f-bis. EFECTOS GLOBALES (retornos de envío) ───────────────────────
	// Leen la SUMA de los envíos de todos los canales y regresan en estéreo
	// al bus principal, antes del master (pasan por su fader y limitador).
	// \on multiplica la salida (1 = suena, 0 = silencio con desvanecimiento).

	// Reverb FreeVerb2: tamano = dimensión del "cuarto", damp = cuánto se
	// apagan los agudos en las reflexiones (1 = cuarto sordo/afelpado).
	SynthDef(\fx_reverb, { |busIn = 0, out = 0, on = 1,
	                        tamano = 0.7, damp = 0.5, retorno = 0|
		var sig, rev;
		sig = In.ar(busIn, 1);
		rev = FreeVerb2.ar(sig, sig, 1, tamano.lag(0.1), damp.lag(0.1));
		Out.ar(out, rev * retorno.dbamp.lag(0.05) * on.lag(0.05));
	}).add;

	// Delay con retroalimentación filtrada: cada eco pasa por un pasa-bajos
	// (filtro), así las repeticiones se van oscureciendo como en un delay de
	// cinta. Mover el tiempo con el delay sonando "estira" el audio (glide
	// de afinación), un accidente clásico que aquí es una función.
	SynthDef(\fx_delay, { |busIn = 0, out = 0, on = 1,
	                       tiempo = 0.4, fb = 0.35, filtro = 3500, retorno = 0|
		var sig, ecos;
		sig  = In.ar(busIn, 1);
		// LocalIn/LocalOut cierran el lazo de retroalimentación dentro del
		// synth (con un bloque de latencia inherente en el lazo).
		ecos = LocalIn.ar(1);
		ecos = DelayC.ar(sig + (ecos * fb.lag(0.1)), 2, tiempo.lag(0.2));
		ecos = LPF.ar(ecos, filtro.lag(0.1));
		LocalOut.ar(ecos);
		Out.ar(out, Pan2.ar(ecos, 0) * retorno.dbamp.lag(0.05) * on.lag(0.05));
	}).add;

	// ── 3g. MASTER: fader general + limitador de seguridad ─────────────────
	SynthDef(\ent_master, { |out = 0, amp = 1, mute = 1|
		var sig;
		sig = In.ar(out, 2);
		sig = sig * amp.lag(0.05) * mute.lag(0.02);
		// Pared absoluta a ~-0.4 dBFS. Con un hidrófono en la boca frente a
		// bocinas, un feedback inesperado puede dispararse a niveles
		// peligrosos para tus oídos y monitores: siempre activo, a propósito.
		sig = Limiter.ar(sig, 0.95, 0.005);
		SendPeakRMS.ar(sig, 20, 3, '/medidorMaster', 0);
		ReplaceOut.ar(out, sig);
	}).add;

	// ── 3h. GRABADOR DE STEM: escribe un tap de canal a disco ──────────────
	// DiskOut es el espejo de DiskIn: va vaciando a disco, por bloques, lo
	// que le llega, a través de un buffer que se abrió con leaveOpen: true.
	SynthDef(\grab_stem, { |busGrab = 0, buf = 0|
		DiskOut.ar(buf, In.ar(busGrab, 1));
	}).add;

	// ── 3i. OSCILOSCOPIO: manda la salida final al buffer del scope ────────
	// Corre DESPUÉS del master (tail del mismo grupo) → lo que ves es
	// exactamente lo que sale por las bocinas, post-limitador.
	SynthDef(\ent_scope, { |scbuf = 0|
		ScopeOut2.ar(In.ar(0, 2), scbuf, 4096);
	}).add;

	// ── 3j. REPRODUCTOR: streaming desde disco (no carga todo a RAM) ───────
	// DiskIn lee el archivo por bloques a través de un buffer "cue", así
	// puedes reproducir sesiones largas sin ocupar memoria. Con loop = 1
	// repite sin cortes (regresa al punto donde se "cueó" el archivo).
	// Cuatro versiones: DiskIn necesita saber el nº de canales al compilar,
	// y el destino cambia el formato — al MASTER se va en estéreo, a la
	// CADENA DE UN CANAL se entra en mono (los archivos estéreo se suman).
	SynthDef(\player1, { |buf = 0, amp = 1, out = 0, loop = 0|
		var sig = DiskIn.ar(1, buf, loop);
		Out.ar(out, (sig * amp.lag(0.05)).dup);   // mono → duplicar a estéreo
	}).add;
	SynthDef(\player2, { |buf = 0, amp = 1, out = 0, loop = 0|
		var sig = DiskIn.ar(2, buf, loop);
		Out.ar(out, sig * amp.lag(0.05));
	}).add;
	SynthDef(\player1c, { |buf = 0, amp = 1, out = 0, loop = 0|
		var sig = DiskIn.ar(1, buf, loop);
		Out.ar(out, sig * amp.lag(0.05));         // mono → bus mono del canal
	}).add;
	SynthDef(\player2c, { |buf = 0, amp = 1, out = 0, loop = 0|
		var sig = DiskIn.ar(2, buf, loop);
		Out.ar(out, sig.sum * 0.5 * amp.lag(0.05));   // estéreo → mono
	}).add;

	// Esperar a que el servidor procese los SynthDefs antes de crear synths.
	s.sync;

	// ═══════════════════════════════════════════════════════════════════════
	// 4. INSTANCIACIÓN
	// ═══════════════════════════════════════════════════════════════════════
	~mute = Array.fill(numCanales, false);
	~solo = Array.fill(numCanales, false);

	~sintEntrada = numCanales.collect { |i|
		Synth(\ent_entrada, [
			\bus, ~busCanal[i], \canalIn, ~cfg[\canales][i][\entrada], \trim, 0
		], ~gEntradas)
	};

	// La cadena del canal se construye por ORDEN DE CREACIÓN dentro de su
	// grupo: head → EQ, luego tail → distorsión, tail → compresor,
	// tail → pitch. Ese orden ES el orden de procesamiento.
	~sintEQ = numCanales.collect { |i|
		Synth.head(~gFxCanal[i], \ent_eq, [\bus, ~busCanal[i]])
	};
	~sintDist = numCanales.collect { |i|
		Synth.tail(~gFxCanal[i], \ins_dist, [\bus, ~busCanal[i], \on, 0])
	};
	~sintComp = numCanales.collect { |i|
		Synth.tail(~gFxCanal[i], \ins_comp, [\bus, ~busCanal[i], \on, 0])
	};
	~sintPitch = numCanales.collect { |i|
		Synth.tail(~gFxCanal[i], \ins_pitch, [\bus, ~busCanal[i], \on, 0])
	};

	~sintSalida = numCanales.collect { |i|
		Synth(\ent_salidaCanal, [
			\bus, ~busCanal[i], \out, 0, \amp, 1, \mute, 1, \pan, 0,
			\idMedidor, i, \busGrab, ~busGrab[i],
			\busRev, ~busRev, \busDel, ~busDel, \sendRev, 0, \sendDel, 0
		], ~gSalidas)
	};

	// Efectos globales de envío (una sola instancia de cada uno):
	~sintRev = Synth(\fx_reverb, [\busIn, ~busRev, \out, 0], ~gFxGlobal);
	~sintDel = Synth(\fx_delay,  [\busIn, ~busDel, \out, 0], ~gFxGlobal);

	~sintMaster = Synth(\ent_master, [\out, 0, \amp, 1, \mute, 1], ~gMaster);
	// El scope se crea al final del grupo master: ve la señal ya limitada.
	~sintScope  = Synth.tail(~gMaster, \ent_scope, [\scbuf, ~scopeBuf.index]);

	// Lógica de mute/solo (vive en el lenguaje): si hay algún solo activo,
	// solo suenan los canales en solo; si no, los no-muteados.
	~actualizarMutes = {
		var haySolo = ~solo.any { |b| b };
		numCanales.do { |i|
			var suena = if(haySolo) { ~solo[i] and: { ~mute[i].not } } { ~mute[i].not };
			~sintSalida[i].set(\mute, suena.asInteger);
		};
	};

	// ═══════════════════════════════════════════════════════════════════════
	// 5. ESTADO DEL REPRODUCTOR Y LA GRABACIÓN
	// ═══════════════════════════════════════════════════════════════════════
	// Las grabaciones van en ./rec/ junto a este archivo (configurable en
	// la sección 0). Si SC no sabe desde qué archivo se evaluó (p. ej.
	// pegaste el código en un documento sin guardar), cae al home como
	// plan B y lo avisa en la post window.
	~dirGrabaciones = if(~rutaScript.notNil) {
		~rutaScript.dirname +/+ ~cfg[\carpetaRec]
	} {
		"⚠ No pude ubicar la carpeta del .scd (¿documento sin guardar?); grabaré en el home.".postln;
		("~/" ++ ~cfg[\carpetaRec]).standardizePath
	};
	File.mkdir(~dirGrabaciones);   // crea la carpeta si no existe
	("Grabaciones → " ++ ~dirGrabaciones).postln;

	// ── Grabación por STEMS: 3 WAVs, uno por canal (post-fader) ────────────
	~sintsStem = nil;
	~bufsStem  = nil;
	~rutasStem = nil;

	// Nombre corto del canal para el archivo: primera línea, en minúsculas
	// ("BOCA\nhidrófono" → "boca").
	~nombreCortoCanal = { |i| nombres[i].split(Char.nl)[0].toLower };

	~iniciaStems = {
		var stamp = Date.getDate.stamp;
		~rutasStem = numCanales.collect { |i|
			~dirGrabaciones +/+
			("sesion_" ++ stamp ++ "_" ++ ~nombreCortoCanal.(i) ++ ".wav")
		};
		~bufsStem = numCanales.collect { Buffer.alloc(s, 65536, 1) };
		// Las operaciones de buffer son asíncronas: sincronizamos con el
		// servidor antes de abrir los archivos y antes de arrancar los
		// synths que escriben en ellos.
		fork {
			s.sync;
			numCanales.do { |i|
				~bufsStem[i].write(~rutasStem[i],
					~cfg[\formatoRec], ~cfg[\bitsRec], 0, 0, true);   // leaveOpen!
			};
			s.sync;
			~sintsStem = numCanales.collect { |i|
				Synth(\grab_stem, [\busGrab, ~busGrab[i], \buf, ~bufsStem[i]], ~gGrab)
			};
			("Grabando stems: "
				++ ~rutasStem.collect { |r| PathName(r).fileName }).postln;
		};
	};

	~detieneStems = {
		~sintsStem.do(_.free);
		~sintsStem = nil;
		~bufsStem.do { |b| b.close; b.free };
		~bufsStem = nil;
		("Stems guardados en: " ++ ~dirGrabaciones).postln;
	};

	~rutaPlayer      = nil;   // archivo cargado en el reproductor
	~duracionPlayer  = 0;     // duración en segundos
	~canalesArchivo  = 2;     // canales del archivo cargado
	~srArchivo       = 48000; // sample rate del archivo cargado
	~tiempoPlayer    = 0;     // posición actual (aprox., en segundos)
	~inicioFrame     = 0;     // frame desde donde arranca (click en la onda)
	~loopPlayer      = false; // repetir sin cortes
	~destPlayer      = 0;     // 0 = master directo; 1..n = cadena del canal n
	~ampPlayer       = 1;     // volumen del reproductor
	~sintPlayer      = nil;
	~bufPlayer       = nil;
	~rutinaPlayer    = nil;

	// mm:ss a partir de segundos
	~fmtTiempo = { |seg|
		(seg / 60).floor.asInteger.asString ++ ":"
		++ (seg % 60).floor.asInteger.asString.padLeft(2, "0")
	};

	// Cargar un archivo al reproductor: leemos sus metadatos con SoundFile
	// (duración, nº de canales) sin cargar el audio.
	~cargarEnPlayer = { |ruta|
		var sf = SoundFile.openRead(ruta);
		if(sf.notNil) {
			if(~sintPlayer.notNil) { ~detenerPlayer.value };
			~rutaPlayer     = ruta;
			~canalesArchivo = sf.numChannels;
			~srArchivo      = sf.sampleRate;
			~duracionPlayer = sf.numFrames / sf.sampleRate;
			~inicioFrame    = 0;
			sf.close;
			{
				var sfVista;
				~lblArchivo.string = PathName(ruta).fileName;
				~lblTiempo.string  = "0:00 / " ++ ~fmtTiempo.(~duracionPlayer);
				~btnPlay.enabled   = true;
				~btnPlay.value     = 0;
				// Cargar la forma de onda en la vista (lee picos, no audio
				// completo a RAM) y regresar el cursor al inicio.
				sfVista = SoundFile.openRead(ruta);
				sfVista !? {
					~vistaOnda.soundfile_(sfVista);
					~vistaOnda.read(0, sfVista.numFrames);
					sfVista.close;
				};
				~vistaOnda.timeCursorPosition = 0;
			}.defer;
		} {
			("No pude abrir el archivo: " ++ ruta).postln;
		};
	};

	// Libera synth + buffer y regresa la GUI a su estado inicial.
	~finalizarPlayer = {
		~sintPlayer !? { ~sintPlayer.free };
		~bufPlayer  !? { ~bufPlayer.close; ~bufPlayer.free };
		~sintPlayer = nil;
		~bufPlayer  = nil;
		~rutinaPlayer = nil;
		~inicioFrame  = 0;
		{
			~btnPlay.value    = 0;
			~lblTiempo.string = "0:00 / " ++ ~fmtTiempo.(~duracionPlayer);
			~vistaOnda.timeCursorPosition = 0;
		}.defer;
	};

	// Detención manual (botón): para el reloj y limpia.
	~detenerPlayer = {
		~rutinaPlayer !? { ~rutinaPlayer.stop };
		~finalizarPlayer.value;
	};

	~iniciarPlayer = {
		// Destino: al MASTER va en estéreo directo a la salida; a un CANAL
		// entra en mono a su bus, ANTES del EQ — pasa por la cadena entera
		// (EQ, dist, comp, pitch, fader y envíos), sumándose al micrófono.
		var aCanal    = ~destPlayer > 0;
		var nombreDef = if(aCanal) {
			if(~canalesArchivo == 1) { \player1c } { \player2c }
		} {
			if(~canalesArchivo == 1) { \player1 } { \player2 }
		};
		var salida = if(aCanal) { ~busCanal[~destPlayer - 1] } { 0 };
		// Para entrar a un canal, el synth debe correr ANTES del grupo de
		// FX de ese canal → va al grupo de entradas, junto a los micrófonos.
		var grupo  = if(aCanal) { ~gEntradas } { ~gPlayer };
		// Buffer.cueSoundFile prepara el archivo para streaming con DiskIn
		// (desde ~inicioFrame: ahí regresa también el loop al dar la vuelta).
		~bufPlayer  = Buffer.cueSoundFile(s, ~rutaPlayer, ~inicioFrame, ~canalesArchivo);
		~sintPlayer = Synth(nombreDef, [
			\buf, ~bufPlayer, \amp, ~ampPlayer, \out, salida,
			\loop, ~loopPlayer.asInteger
		], grupo);
		~tiempoPlayer = ~inicioFrame / ~srArchivo;
		// Reloj de reproducción: corre en AppClock (el hilo de la GUI),
		// por eso puede actualizar la etiqueta y el cursor directamente.
		~rutinaPlayer = Routine({
			while { ~sintPlayer.notNil and: { ~loopPlayer or: { ~tiempoPlayer < ~duracionPlayer } } } {
				if(~tiempoPlayer >= ~duracionPlayer) {
					// el loop dio la vuelta: regresa al punto de arranque
					~tiempoPlayer = ~inicioFrame / ~srArchivo;
				};
				~lblTiempo.string = ~fmtTiempo.(~tiempoPlayer)
					++ " / " ++ ~fmtTiempo.(~duracionPlayer);
				~vistaOnda.timeCursorPosition = (~tiempoPlayer * ~srArchivo).asInteger;
				0.1.wait;
				~tiempoPlayer = ~tiempoPlayer + 0.1;
			};
			// El archivo llegó a su fin de forma natural:
			if(~sintPlayer.notNil) { ~finalizarPlayer.value };
		}).play(AppClock);
	};

	// Saltar a un frame del archivo (click en la forma de onda). Si está
	// sonando, re-arranca ahí mismo con el mismo destino; si no, solo deja
	// listo el punto de arranque para el siguiente PLAY.
	~saltarA = { |frame|
		frame = frame.clip(0, ((~duracionPlayer * ~srArchivo) - 1).max(0)).asInteger;
		~inicioFrame = frame;
		if(~sintPlayer.notNil) {
			~rutinaPlayer !? { ~rutinaPlayer.stop };
			~sintPlayer.free;
			~sintPlayer = nil;
			~bufPlayer !? { ~bufPlayer.close; ~bufPlayer.free; ~bufPlayer = nil };
			~iniciarPlayer.value;
		} {
			~tiempoPlayer = frame / ~srArchivo;
			{
				~vistaOnda.timeCursorPosition = frame;
				~lblTiempo.string = ~fmtTiempo.(~tiempoPlayer)
					++ " / " ++ ~fmtTiempo.(~duracionPlayer);
			}.defer;
		};
	};

	// ═══════════════════════════════════════════════════════════════════════
	// 6. INTERFAZ GRÁFICA
	// ═══════════════════════════════════════════════════════════════════════

	// ── Paleta ──────────────────────────────────────────────────────────────
	colFondo       = Color.new255(16, 16, 20);
	colStrip       = Color.new255(26, 27, 33);
	colStripMaster = Color.new255(33, 30, 36);
	colAcento      = Color.new255(228, 122, 82);
	colTexto       = Color.gray(0.82);
	colTextoSuave  = Color.gray(0.55);
	colRojo        = Color.new255(214, 72, 72);
	colVerde       = Color.new255(120, 190, 120);
	colAzul        = Color.new255(110, 155, 214);
	colRejilla     = Color.gray(0.28);

	fuente       = Font.sansSerif(10);
	fuentePeq    = Font.sansSerif(8);
	fuenteTitulo = Font.sansSerif(11, bold: true);
	fuenteApp    = Font.sansSerif(16, bold: true);

	// ── ControlSpecs: posición del control (0..1) ↔ valor real ─────────────
	// \exp para frecuencias y tiempos (percepción logarítmica), \lin para dB.
	specTrim      = ControlSpec(-24, 24, \lin, units: "dB");
	specPan       = ControlSpec(-1, 1, \lin, units: "");
	specHPF       = ControlSpec(20, 600, \exp, units: "Hz");
	specLoF       = ControlSpec(40, 500, \exp, units: "Hz");
	specMidF      = ControlSpec(100, 8000, \exp, units: "Hz");
	specMidQ      = ControlSpec(0.3, 8, \exp, units: "");
	specHiF       = ControlSpec(1500, 16000, \exp, units: "Hz");
	specGain      = ControlSpec(-18, 18, \lin, units: "dB");
	specFader     = ControlSpec(-60, 6, \lin, units: "dB");
	specDrive     = ControlSpec(1, 30, \exp, units: "");
	specMezcla    = ControlSpec(0, 1, \lin, units: "");
	specThr       = ControlSpec(-60, 0, \lin, units: "dB");
	specRatio     = ControlSpec(1, 20, \exp, units: ":1");
	specAtk       = ControlSpec(0.0005, 0.05, \exp, units: "s");
	specRel       = ControlSpec(0.02, 1, \exp, units: "s");
	specMakeup    = ControlSpec(0, 24, \lin, units: "dB");
	specVolPlayer = ControlSpec(-40, 6, \lin, units: "dB");
	specPitch     = ControlSpec(0.25, 4, \exp, units: "x");
	specDisp      = ControlSpec(0, 1, \lin, units: "");
	specTiempoDel = ControlSpec(0.02, 2, \exp, units: "s");
	specFb        = ControlSpec(0, 0.95, \lin, units: "");
	specFiltroDel = ControlSpec(200, 12000, \exp, units: "Hz");
	specRetorno   = ControlSpec(-60, 6, \lin, units: "dB");

	// Formateo legible del valor según sus unidades.
	~formatea = { |spec, v|
		case
		{ spec.units == "Hz" } {
			if(v >= 1000) { (v / 1000).round(0.1).asString ++ "kHz" }
			{ v.round(1).asInteger.asString ++ "Hz" }
		}
		{ spec.units == "s" } { (v * 1000).round(0.1).asString ++ "ms" }
		{ spec.units == "dB" } { v.round(0.1).asString ++ "dB" }
		{ spec.units == ":1" } { v.round(0.1).asString ++ ":1" }
		{ spec.units == "x" } { v.round(0.01).asString ++ "x" }
		{ v.round(0.01).asString };
	};

	// ── Entrada manual de valores (doble click en perillas y faders) ────────
	// Interpreta lo tecleado en las unidades que muestra la etiqueta:
	// Hz (con sufijo "k" para kHz), ms para los tiempos, dB, etc.
	// Lo que no se pueda leer como número queda en el mínimo del spec —
	// constrain siempre regresa algo dentro del rango, nunca truena.
	~parseaValor = { |str, spec|
		var t = str.asString.toLower.replace(",", ".").replace(" ", "");
		var mult = 1;
		if(spec.units == "Hz" and: { t.contains("k") }) { mult = 1000 };
		if(spec.units == "s") { mult = 0.001 };   // la etiqueta muestra ms
		spec.constrain(t.asFloat * mult)
	};

	// Ventanita con un campo de texto: Enter aplica, Esc cancela.
	~pideValor = { |nombre, spec, actual, alAceptar|
		var w, tf, pista, mostrado;
		pista = case
			{ spec.units == "Hz" } { "Hz — acepta 2k = 2000" }
			{ spec.units == "s" }  { "ms" }
			{ spec.units == "dB" } { "dB" }
			{ spec.units == ":1" } { "proporción (n:1)" }
			{ spec.units == "x" }  { "factor (1 = sin cambio)" }
			{ "número" };
		mostrado = if(spec.units == "s") { (actual * 1000).round(0.1) } { actual.round(0.001) };
		w = Window(nombre, Rect(500, 400, 210, 66), resizable: false)
			.alwaysOnTop_(true).background_(colFondo);
		tf = TextField().font_(fuente).string_(mostrado.asString);
		tf.action = { |t|
			alAceptar.(~parseaValor.(t.string, spec));
			w.close;
		};
		w.view.keyDownAction = { |v, char, mod, uni|
			if(uni == 27) { w.close };   // Esc
		};
		w.layout = VLayout(
			StaticText().string_(nombre ++ "  ·  " ++ pista)
				.font_(fuentePeq).stringColor_(colTextoSuave),
			tf
		).margins_(6).spacing_(3);
		w.front;
		tf.focus;
	};

	// ── Registro de controles ───────────────────────────────────────────────
	// Cada perilla se registra aquí con su spec y su valor por defecto.
	// Esto habilita tres funciones con el mismo mecanismo:
	//   · RESET por canal (regresar perillas al default)
	//   · PRESETS (guardar/cargar el estado completo)
	//   · MIDI (los mapas apuntan a estas mismas claves)
	~reg      = Array.fill(numCanales, { IdentityDictionary.new });
	~regFx    = IdentityDictionary.new;   // perillas de la columna FX global
	~btnHPF   = Array.newClear(numCanales);
	~btnDist  = Array.newClear(numCanales);
	~btnComp  = Array.newClear(numCanales);
	~btnPitch = Array.newClear(numCanales);
	~btnsMute = Array.newClear(numCanales);
	~faders   = Array.newClear(numCanales);
	~medidores = Array.newClear(numCanales + 2);   // 3 canales + master L/R

	// ── Estado de los PRESETS RÁPIDOS (slots) ───────────────────────────────
	~numSlots        = ~cfg[\notasSlots].size;
	~slots           = Array.newClear(~numSlots);   // un estado completo por slot
	~slotActivo      = nil;
	~modoGuardarSlot = false;                       // armado por [GUARDAR EN…]

	// ── Estado y dibujo de la CURVA DE EQ ───────────────────────────────────
	// Guardamos los valores actuales del EQ de cada canal en un Event;
	// las perillas los actualizan y la vista se redibuja leyendo de aquí.
	~eqVals = numCanales.collect {
		(hpfOn: 1, hpfFreq: 80, loFreq: 180, loGain: 0,
		 midFreq: 800, midGain: 0, midQ: 1, hiFreq: 5000, hiGain: 0)
	};
	~vistasEQ = Array.newClear(numCanales);

	// Respuesta aproximada en dB del EQ completo a la frecuencia f.
	// Aproximaciones analógicas clásicas — suficientes para VER la curva:
	//   · HPF Butterworth 2º orden:  |H| = r² / √(1 + r⁴),  r = f/fc
	//   · shelf grave:   g / (1 + (f/fc)²)      (g se desvanece hacia arriba)
	//   · shelf agudo:   g / (1 + (fc/f)²)      (g se desvanece hacia abajo)
	//   · campana:       g / (1 + Q²·(f/fc − fc/f)²)
	~calculaEQdB = { |p, f|
		var db = 0, r;
		if(p[\hpfOn] == 1) {
			r  = f / p[\hpfFreq];
			db = db + (20 * (r.squared / (1 + r.pow(4)).sqrt).max(1e-6).log10);
		};
		db = db + (p[\loGain]  / (1 + (f / p[\loFreq]).squared));
		db = db + (p[\hiGain]  / (1 + (p[\hiFreq] / f).squared));
		db = db + (p[\midGain] / (1 + (p[\midQ] * ((f / p[\midFreq]) - (p[\midFreq] / f))).squared));
		db
	};

	// Fábrica de la vista de curva: eje X logarítmico 20 Hz–20 kHz,
	// eje Y ±24 dB. Se redibuja cada vez que giras una perilla del EQ.
	~hazVistaEQ = { |i|
		var v = UserView().fixedHeight_(64).minWidth_(120)
			.toolTip_("Curva de respuesta del EQ de este canal\n(HPF + 3 bandas). Rejilla: 100 Hz, 1 kHz, 10 kHz · 0 y ±12 dB.");
		v.drawFunc = { |vw|
			var w = vw.bounds.width, h = vw.bounds.height;
			var p = ~eqVals[i];
			var fmin = 20, fmax = 20000, dbMax = 24;
			var aY = { |db| (0.5 - (db / (dbMax * 2))) * h };
			var aX = { |f| (f / fmin).log / (fmax / fmin).log * w };

			Pen.fillColor = colFondo;
			Pen.fillRect(Rect(0, 0, w, h));

			// Rejilla: 100 Hz / 1 kHz / 10 kHz y 0 / ±12 dB
			Pen.strokeColor = colRejilla;
			Pen.width = 0.5;
			[100, 1000, 10000].do { |f|
				Pen.line(Point(aX.(f), 0), Point(aX.(f), h));
			};
			[-12, 12].do { |db|
				Pen.line(Point(0, aY.(db)), Point(w, aY.(db)));
			};
			Pen.stroke;
			Pen.strokeColor = Color.gray(0.4);
			Pen.line(Point(0, aY.(0)), Point(w, aY.(0)));   // línea de 0 dB
			Pen.stroke;

			// La curva
			Pen.strokeColor = colAcento;
			Pen.width = 1.5;
			Pen.moveTo(Point(0, aY.(~calculaEQdB.(p, fmin).clip(dbMax.neg, dbMax))));
			(2, 4 .. w).do { |x|
				var f  = fmin * ((fmax / fmin) ** (x / w));
				var db = ~calculaEQdB.(p, f).clip(dbMax.neg, dbMax);
				Pen.lineTo(Point(x, aY.(db)));
			};
			Pen.stroke;
		};
		~vistasEQ[i] = v;
		v
	};

	// Actualiza un parámetro del EQ: synth + estado + redibujo de la curva.
	~setEQ = { |i, clave, v|
		~sintEQ[i].set(clave, v);
		~eqVals[i][clave] = v;
		~vistasEQ[i] !? { |vw| vw.refresh };
	};

	// ── Fábrica de perillas ─────────────────────────────────────────────────
	// canal: índice para registrarla (nil = no registrar, p. ej. el volumen
	//        del reproductor; \fx = columna de efectos globales).
	// accion: recibe el valor YA mapeado cada vez que giras la perilla.
	// ancho: tamaño de la perilla (32 normal; 24 = compacta, p. ej. envíos).
	hazKnob = { |canal, clave, nombre, tip, spec, inicial, accion, ancho = 32|
		var k, lNombre, lValor;

		k = Knob()
			.mode_(\vert)                       // arrastre vertical
			.fixedWidth_(ancho).fixedHeight_(ancho)
			.color_([colStrip, colAcento, colFondo, colTexto])
			.toolTip_(tip ++ "\n(Doble click: escribir el valor a mano.)");

		// Doble click → ventanita para teclear el valor exacto.
		k.mouseDownAction = { |view, x, y, mods, boton, clicks|
			if(clicks == 2) {
				~pideValor.(nombre, spec, spec.map(k.value), { |v|
					k.valueAction_(spec.unmap(v));
				});
			};
		};

		lValor = StaticText().string_(~formatea.(spec, inicial))
			.align_(\center).font_(fuentePeq).stringColor_(colAcento);
		lNombre = StaticText().string_(nombre)
			.align_(\center).font_(fuentePeq).stringColor_(colTexto);

		k.value = spec.unmap(inicial);          // valor real → posición 0..1
		k.action = { |kn|
			var v = spec.map(kn.value);         // posición 0..1 → valor real
			lValor.string = ~formatea.(spec, v);
			accion.(v);
		};

		// Registrar para reset/presets/MIDI. valueAction_ (usado por los
		// tres) mueve la perilla Y dispara su acción → GUI y synth al día.
		// canal = \fx registra en la columna de efectos globales.
		if(canal.notNil) {
			if(canal == \fx) {
				~regFx[clave] = (knob: k, spec: spec, default: inicial);
			} {
				~reg[canal][clave] = (knob: k, spec: spec, default: inicial);
			};
		};

		VLayout([k, align: \center], lValor, lNombre).spacing_(1)
	};

	// Encabezado de sección con botón de encendido (DIST, COMP, PITCH).
	hazSeccion = { |texto, tip, accionOn|
		var btn, lbl;
		lbl = StaticText().string_(texto).font_(fuentePeq)
			.stringColor_(colTextoSuave);
		btn = Button()
			.states_([["off", colTextoSuave, colStrip], ["ON", Color.black, colAcento]])
			.font_(fuentePeq).fixedWidth_(36).maxHeight_(16)
			.toolTip_(tip)
			.action_({ |b| accionOn.(b.value) });
		[HLayout(lbl, nil, btn), btn]   // regresa el layout y el botón
	};

	// ── RESET de un canal ────────────────────────────────────────────────────
	// Regresa todas las perillas registradas a su default y apaga/enciende
	// los procesadores como al inicio (HPF on, dist/comp/pitch off).
	// NO toca el fader ni mute/solo: en vivo, un salto de volumen es peligroso.
	~resetCanal = { |i|
		~reg[i].do { |e|
			e[\knob].valueAction_(e[\spec].unmap(e[\default]));
		};
		~btnHPF[i].valueAction_(1);
		~btnDist[i].valueAction_(0);
		~btnComp[i].valueAction_(0);
		~btnPitch[i].valueAction_(0);
	};

	// ── RESET de la columna FX ──────────────────────────────────────────────
	// Regresa reverb y delay a sus valores por defecto, encendidos.
	~resetFx = {
		~regFx.do { |e|
			e[\knob].valueAction_(e[\spec].unmap(e[\default]));
		};
		~btnRev.valueAction_(1);
		~btnDel.valueAction_(1);
	};

	// ── ESTADO COMPLETO: capturar / aplicar ─────────────────────────────────
	// Un "estado" es un Event con todas las perillas, los procesadores
	// encendidos y los faders. Es la moneda común de tres mecanismos:
	// los presets de archivo, los PRESETS RÁPIDOS (slots) y — vía
	// valueAction — la GUI y los synths quedan al día al aplicarlo.
	~capturaEstado = {
		var d = ();
		d[\canales] = numCanales.collect { |i|
			var c = ();
			~reg[i].keysValuesDo { |k, e| c[k] = e[\spec].map(e[\knob].value) };
			c[\hpfOn]   = ~btnHPF[i].value;
			c[\distOn]  = ~btnDist[i].value;
			c[\compOn]  = ~btnComp[i].value;
			c[\pitchOn] = ~btnPitch[i].value;
			c[\fader]   = specFader.map(~faders[i].value);
			c
		};
		d[\master] = specFader.map(~faderMaster.value);
		d[\fx] = {
			var f = ();
			~regFx.keysValuesDo { |k, e| f[k] = e[\spec].map(e[\knob].value) };
			f[\revOn] = ~btnRev.value;
			f[\delOn] = ~btnDel.value;
			f
		}.value;
		d
	};

	// Regresa true si el estado era válido y se aplicó.
	~aplicaEstado = { |d|
		if(d.notNil and: { d[\canales].notNil }) {
			d[\canales].do { |c, i|
				if(i < numCanales) {
					~reg[i].keysValuesDo { |k, e|
						if(c[k].notNil) {
							e[\knob].valueAction_(e[\spec].unmap(c[k]));
						};
					};
					~btnHPF[i].valueAction_(c[\hpfOn] ? 1);
					~btnDist[i].valueAction_(c[\distOn] ? 0);
					~btnComp[i].valueAction_(c[\compOn] ? 0);
					~btnPitch[i].valueAction_(c[\pitchOn] ? 0);
					~faders[i].valueAction_(specFader.unmap(c[\fader] ? 0));
				};
			};
			~faderMaster.valueAction_(specFader.unmap(d[\master] ? 0));
			// FX globales (presets viejos sin esta sección: se quedan como están)
			if(d[\fx].notNil) {
				~regFx.keysValuesDo { |k, e|
					if(d[\fx][k].notNil) {
						e[\knob].valueAction_(e[\spec].unmap(d[\fx][k]));
					};
				};
				~btnRev.valueAction_(d[\fx][\revOn] ? 1);
				~btnDel.valueAction_(d[\fx][\delOn] ? 1);
			};
			// Que los anillos del controlador sigan al nuevo estado:
			~refrescaLEDs.value;
			true
		} {
			false
		};
	};

	// ── PRESETS RÁPIDOS (slots): cambiar de estado con UN botón ─────────────
	~guardarSlot = { |n|
		~slots[n] = ~capturaEstado.value;
		~slotActivo = n;
		~modoGuardarSlot = false;
		~btnGuardarEn.value = 0;
		~pintaSlots.value;
		("Preset rápido guardado en el slot " ++ (n + 1) ++ ".").postln;
	};

	~cargarSlot = { |n|
		if(~slots[n].notNil) {
			~aplicaEstado.(~slots[n]);
			~slotActivo = n;
			~pintaSlots.value;
			("Preset rápido " ++ (n + 1) ++ " cargado.").postln;
		} {
			("El slot " ++ (n + 1) ++ " está vacío — guárdale algo con [GUARDAR EN…].").postln;
		};
	};

	// ── PRESETS de archivo: guardar / cargar el estado completo ─────────────
	// Serializamos un Event (diccionario) con writeArchive — formato binario
	// nativo de SC, se lee de vuelta con Object.readArchive. El archivo
	// incluye TAMBIÉN los presets rápidos de la sesión.
	~guardarPreset = {
		Dialog.savePanel({ |ruta|
			var d = ~capturaEstado.value;
			d[\slots] = ~slots.copy;
			d.writeArchive(ruta);
			("Preset guardado en: " ++ ruta).postln;
		});
	};

	~cargarPreset = {
		Dialog.openPanel({ |ruta|
			var d = Object.readArchive(ruta);
			if(~aplicaEstado.(d)) {
				if(d[\slots].notNil) {
					// collect por índice: si el archivo viene de una config
					// con otro número de slots, sobra o falta sin tronar.
					~slots = ~numSlots.collect { |n| d[\slots][n] };
				};
				~slotActivo = nil;
				~pintaSlots.value;
				("Preset cargado: " ++ ruta).postln;
			} {
				"El archivo no parece ser un preset de esta mezcladora.".postln;
			};
		});
	};

	// ── Fábrica de canal completo (strip) ───────────────────────────────────
	hazStrip = { |i|
		var titulo, vistaEQ, rejillaEQ, btnHPF, secDist, rejillaDist, secComp,
		    rejillaComp, secPitch, rejillaPitch, rejillaSends, btnMute, btnSolo,
		    btnReset, lFader, fader, medidor, colFader, contenedor;

		titulo = StaticText().string_(nombres[i]).align_(\center)
			.font_(fuenteTitulo).stringColor_(colAcento);

		// —— Curva del EQ ——
		vistaEQ = ~hazVistaEQ.(i);

		// —— EQ (3×3 + Q) ——
		// Las perillas del EQ pasan por ~setEQ: además de mover el synth,
		// actualizan la curva dibujada arriba.
		rejillaEQ = GridLayout.rows(
			[
				hazKnob.(i, \trim, "TRIM",
					"Ganancia digital de entrada, antes de todo el procesamiento.\nSúbela hasta que el medidor llegue cómodo sin tocar el rojo.",
					specTrim, 0, { |v| ~sintEntrada[i].set(\trim, v) }),
				hazKnob.(i, \pan, "PAN",
					"Posición del canal en el campo estéreo (izquierda ↔ derecha).",
					specPan, 0, { |v| ~sintSalida[i].set(\pan, v) }),
				hazKnob.(i, \hpfFreq, "HPF",
					"Frecuencia de corte del filtro pasa-altos: elimina lo que está\npor debajo. Esencial en los piezos contra retumbe y ruido de manejo.",
					specHPF, 80, { |v| ~setEQ.(i, \hpfFreq, v) })
			],
			[
				hazKnob.(i, \loFreq, "LO f",
					"Frecuencia del shelf grave: desde aquí hacia abajo\nse aplica la ganancia LO g.",
					specLoF, 180, { |v| ~setEQ.(i, \loFreq, v) }),
				hazKnob.(i, \midFreq, "MID f",
					"Frecuencia central de la campana media.",
					specMidF, 800, { |v| ~setEQ.(i, \midFreq, v) }),
				hazKnob.(i, \hiFreq, "HI f",
					"Frecuencia del shelf agudo: desde aquí hacia arriba\nse aplica la ganancia HI g.",
					specHiF, 5000, { |v| ~setEQ.(i, \hiFreq, v) })
			],
			[
				hazKnob.(i, \loGain, "LO g",
					"Ganancia (±dB) de la banda grave.",
					specGain, 0, { |v| ~setEQ.(i, \loGain, v) }),
				hazKnob.(i, \midGain, "MID g",
					"Ganancia (±dB) de la campana media.",
					specGain, 0, { |v| ~setEQ.(i, \midGain, v) }),
				hazKnob.(i, \hiGain, "HI g",
					"Ganancia (±dB) de la banda aguda.",
					specGain, 0, { |v| ~setEQ.(i, \hiGain, v) })
			],
			[
				hazKnob.(i, \midQ, "MID Q",
					"Ancho de la campana media: Q alto = campana angosta\n(quirúrgica), Q bajo = campana ancha (musical).",
					specMidQ, 1, { |v| ~setEQ.(i, \midQ, v) }),
				nil, nil
			]
		).spacing_(2);

		btnHPF = Button()
			.states_([["HPF off", colTextoSuave, colStrip], ["HPF ON", Color.black, colAcento]])
			.font_(fuentePeq).maxHeight_(18)
			.toolTip_("Activa/desactiva el filtro pasa-altos.")
			.value_(1)
			.action_({ |b| ~setEQ.(i, \hpfOn, b.value) });
		~btnHPF[i] = btnHPF;

		// —— DISTORSIÓN ——
		secDist = hazSeccion.("DISTORSIÓN",
			"Activa/desactiva la saturación de este canal.",
			{ |v| ~sintDist[i].set(\on, v) });
		~btnDist[i] = secDist[1];

		rejillaDist = GridLayout.rows([
			hazKnob.(i, \drive, "DRIVE",
				"Cantidad de saturación (curva tanh). Más drive =\nmás armónicos y compresión natural del pico.",
				specDrive, 4, { |v| ~sintDist[i].set(\drive, v) }),
			hazKnob.(i, \mezcla, "MEZCLA",
				"Balance limpio (0) ↔ distorsionado (1).\nValores medios = distorsión paralela: conservas el detalle\nfino de la señal y sumas la textura saturada.",
				specMezcla, 0.5, { |v| ~sintDist[i].set(\mezcla, v) }),
			nil
		]).spacing_(2);

		// —— COMPRESOR ——
		secComp = hazSeccion.("COMPRESOR",
			"Activa/desactiva el compresor de este canal.",
			{ |v| ~sintComp[i].set(\on, v) });
		~btnComp[i] = secComp[1];

		rejillaComp = GridLayout.rows(
			[
				hazKnob.(i, \umbral, "THR",
					"Umbral: nivel a partir del cual el compresor\nempieza a reducir ganancia.",
					specThr, -20, { |v| ~sintComp[i].set(\umbral, v) }),
				hazKnob.(i, \ratio, "RATIO",
					"Proporción de reducción sobre el umbral:\n4:1 = de cada 4 dB que suben, sale 1.",
					specRatio, 4, { |v| ~sintComp[i].set(\ratio, v) }),
				hazKnob.(i, \makeup, "MAKEUP",
					"Ganancia de compensación después de comprimir:\nrecupera el nivel que la compresión bajó.",
					specMakeup, 0, { |v| ~sintComp[i].set(\makeup, v) })
			],
			[
				hazKnob.(i, \atk, "ATK",
					"Ataque: qué tan rápido reacciona el compresor al superar\nel umbral. Lento deja pasar el transitorio (más 'punch').",
					specAtk, 0.005, { |v| ~sintComp[i].set(\atk, v) }),
				hazKnob.(i, \rel, "REL",
					"Relajación: cuánto tarda en soltar la compresión\ncuando la señal baja del umbral.",
					specRel, 0.1, { |v| ~sintComp[i].set(\rel, v) }),
				nil
			]
		).spacing_(2);

		// —— PITCH SHIFTER ——
		secPitch = hazSeccion.("PITCH",
			"Activa/desactiva el pitch shifter granular de este canal.",
			{ |v| ~sintPitch[i].set(\on, v) });
		~btnPitch[i] = secPitch[1];

		rejillaPitch = GridLayout.rows([
			hazKnob.(i, \pitchRatio, "PITCH",
				"Transposición: 0.5x = una octava abajo, 1x = sin cambio,\n2x = una octava arriba. Granular: no altera la duración.",
				specPitch, 1, { |v| ~sintPitch[i].set(\ratio, v) }),
			hazKnob.(i, \pitchDisp, "DISP",
				"Dispersión de los granos (afinación y tiempo).\nValores altos deshacen la voz en textura granular pura.",
				specDisp, 0, { |v| ~sintPitch[i].set(\disp, v) }),
			hazKnob.(i, \pitchMezcla, "MEZCLA",
				"Balance sin transponer (0) ↔ transpuesto (1).\nValores medios superponen la voz original y su sombra.",
				specMezcla, 1, { |v| ~sintPitch[i].set(\mezcla, v) })
		]).spacing_(2);

		// —— Columna derecha: mute/solo, fader, medidor, reset ——
		btnMute = Button()
			.states_([["M", colTexto, colStrip], ["M", Color.white, colRojo]])
			.font_(fuente).maxHeight_(22)
			.toolTip_("Mute: silencia este canal.")
			.action_({ |b|
				~mute[i] = (b.value == 1);
				~actualizarMutes.();
				// El LED del botón de mute del controlador sigue al estado:
				~cfg[\notasMute][i] !? { |n| ~ledNota.(n, b.value == 1) };
			});
		~btnsMute[i] = btnMute;

		btnSolo = Button()
			.states_([["S", colTexto, colStrip], ["S", Color.black, colVerde]])
			.font_(fuente).maxHeight_(22)
			.toolTip_("Solo: silencia todos los demás canales.")
			.action_({ |b| ~solo[i] = (b.value == 1); ~actualizarMutes.() });

		// —— Envíos post-fader a los efectos globales (columna FX) ——
		rejillaSends = HLayout(
			hazKnob.(i, \sendRev, "REV",
				"Envío de este canal a la REVERB global (post-fader):\ncuánto de este micrófono entra al cuarto reverberante.",
				specMezcla, 0, { |v| ~sintSalida[i].set(\sendRev, v) }),
			hazKnob.(i, \sendDel, "DLY",
				"Envío de este canal al DELAY global (post-fader):\ncuánto de este micrófono entra al eco.",
				specMezcla, 0, { |v| ~sintSalida[i].set(\sendDel, v) })
		).spacing_(1);

		lFader = StaticText().string_("0.0dB").align_(\center)
			.font_(fuentePeq).stringColor_(colTexto);

		// El fader trabaja en dB en la GUI, pero al synth le mandamos
		// AMPLITUD lineal. Bajo -59.5 dB lo tratamos como silencio (-inf).
		fader = Slider()
			.maxWidth_(~cfg[\anchoFader]).minHeight_(120)
			.toolTip_("Fader del canal: nivel con el que entra a la mezcla.\n(Doble click: escribir el valor en dB a mano.)")
			.value_(specFader.unmap(0))
			.action_({ |sl|
				var db  = specFader.map(sl.value);
				var amp = if(db <= -59.5) { 0 } { db.dbamp };
				lFader.string = if(db <= -59.5) { "-inf" } { db.round(0.1).asString ++ "dB" };
				~sintSalida[i].set(\amp, amp);
			});
		fader.mouseDownAction = { |view, x, y, mods, boton, clicks|
			if(clicks == 2) {
				~pideValor.("FADER " ++ ~nombreCortoCanal.(i).toUpper, specFader,
					specFader.map(fader.value),
					{ |v| fader.valueAction_(specFader.unmap(v)) });
			};
		};
		~faders[i] = fader;

		medidor = LevelIndicator()
			.maxWidth_(~cfg[\anchoMedidor]).minHeight_(120)
			.warning_(0.85).critical_(0.97).drawsPeak_(true)
			.toolTip_("Nivel post-fader del canal (RMS + pico).");
		~medidores[i] = medidor;

		btnReset = Button()
			.states_([["RESET", colAzul, colStrip]])
			.font_(fuentePeq).maxHeight_(20)
			.toolTip_("Regresa todas las perillas de este canal a sus valores\npor defecto (HPF on; dist, comp y pitch off).\nNo toca fader ni mute/solo.")
			.action_({ ~resetCanal.(i) });

		// La columna del fader vive en un contenedor de ANCHO FIJO
		// (~cfg[\anchoColFader]): así el espacio sobrante del strip se lo
		// queda el lado del EQ y no se abre un hueco junto al fader.
		colFader = View().fixedWidth_(~cfg[\anchoColFader]);
		colFader.layout = VLayout(
			HLayout(btnMute, btnSolo).spacing_(3),
			rejillaSends,
			lFader,
			[HLayout([fader, align: \center], [medidor, align: \center]).spacing_(4), stretch: 1],
			btnReset
		).margins_(0).spacing_(3);

		contenedor = View().background_(colStrip);
		contenedor.layout = HLayout(
			VLayout(
				titulo,
				vistaEQ,
				rejillaEQ,
				btnHPF,
				secDist[0],
				rejillaDist,
				secComp[0],
				rejillaComp,
				secPitch[0],
				rejillaPitch,
				nil
			).spacing_(3),
			colFader
		).margins_(7).spacing_(5);

		contenedor
	};

	// ── Columna FX: reverb y delay globales (retornos de envío) ─────────────
	// Una sola instancia de cada efecto; los canales les mandan señal con
	// sus perillas REV/DLY (junto a cada fader). Aquí se moldea el efecto
	// en sí y su nivel de retorno a la mezcla.
	stripFx = {
		var titulo, secRev, rejillaRev, secDel, rejillaDel, btnTap,
		    btnResetFx, nota, contenedor;

		titulo = StaticText().string_("FX").align_(\center)
			.font_(fuenteTitulo).stringColor_(colAcento);

		secRev = hazSeccion.("REVERB",
			"Activa/desactiva la reverb global.\nLos canales le mandan señal con su perilla REV.",
			{ |v| ~sintRev.set(\on, v) });
		~btnRev = secRev[1];
		~btnRev.value = 1;   // encendida por defecto (sin envíos no suena)

		rejillaRev = GridLayout.rows([
			hazKnob.(\fx, \revTamano, "TAMAÑO",
				"Dimensión del cuarto reverberante:\npequeño y seco (0) ↔ caverna (1).",
				specMezcla, 0.7, { |v| ~sintRev.set(\tamano, v) }),
			hazKnob.(\fx, \revDamp, "DAMP",
				"Amortiguación de agudos en las reflexiones:\n0 = cuarto brillante, 1 = cuarto sordo/afelpado.",
				specMezcla, 0.5, { |v| ~sintRev.set(\damp, v) }),
			hazKnob.(\fx, \revRetorno, "RET",
				"Nivel con el que la reverb regresa a la mezcla\n(pasa por el fader master y el limitador).",
				specRetorno, 0, { |v| ~sintRev.set(\retorno, v) })
		]).spacing_(2);

		secDel = hazSeccion.("DELAY",
			"Activa/desactiva el delay global.\nLos canales le mandan señal con su perilla DLY.",
			{ |v| ~sintDel.set(\on, v) });
		~btnDel = secDel[1];
		~btnDel.value = 1;   // encendido por defecto (sin envíos no suena)

		rejillaDel = GridLayout.rows(
			[
				hazKnob.(\fx, \delTiempo, "TIEMPO",
					"Tiempo entre repeticiones. Moverlo con el delay sonando\n'estira' el audio (glide de afinación, estilo cinta).",
					specTiempoDel, 0.4, { |v| ~sintDel.set(\tiempo, v) }),
				hazKnob.(\fx, \delFb, "FB",
					"Retroalimentación: cuánto de cada eco vuelve a entrar.\nCerca del máximo, los ecos casi no decaen.",
					specFb, 0.35, { |v| ~sintDel.set(\fb, v) }),
				hazKnob.(\fx, \delFiltro, "FILTRO",
					"Pasa-bajos dentro del lazo: cada repetición se va\noscureciendo, como en un delay de cinta.",
					specFiltroDel, 3500, { |v| ~sintDel.set(\filtro, v) })
			],
			[
				hazKnob.(\fx, \delRetorno, "RET",
					"Nivel con el que el delay regresa a la mezcla\n(pasa por el fader master y el limitador).",
					specRetorno, 0, { |v| ~sintDel.set(\retorno, v) }),
				nil, nil
			]
		).spacing_(2);

		// TAP: marca el pulso a toques y el TIEMPO del delay se fija al
		// intervalo entre los dos últimos. Pasa por la perilla (valueAction)
		// → GUI, synth, presets y LEDs quedan sincronizados.
		btnTap = Button()
			.states_([["TAP", Color.black, colAcento]])
			.font_(fuente).maxHeight_(24)
			.toolTip_("Marca el pulso: dos o más toques seguidos fijan el TIEMPO\ndel delay al intervalo entre ellos (entre 20 ms y 2 s).\nMás de 2.5 s sin tocar reinicia la cuenta.")
			.action_({
				var ahora = Main.elapsedTime, e;
				if(~ultimoTap.notNil and: { (ahora - ~ultimoTap) < 2.5 }) {
					e = ~regFx[\delTiempo];
					e[\knob].valueAction_(e[\spec].unmap(ahora - ~ultimoTap));
				};
				~ultimoTap = ahora;
			});

		btnResetFx = Button()
			.states_([["RESET", colAzul, colStrip]])
			.font_(fuentePeq).maxHeight_(20)
			.toolTip_("Regresa la reverb y el delay a sus valores por defecto\n(ambos encendidos). No toca los envíos de los canales.")
			.action_({ ~resetFx.value });

		nota = StaticText()
			.string_("los envíos REV / DLY\nviven junto a cada fader")
			.align_(\center).font_(fuentePeq).stringColor_(colTextoSuave);

		contenedor = View().background_(colStrip);
		contenedor.layout = VLayout(
			titulo,
			secRev[0],
			rejillaRev,
			secDel[0],
			rejillaDel,
			btnTap,
			nota,
			nil,
			btnResetFx
		).margins_(7).spacing_(3);

		contenedor
	}.value;

	// ── Strip del MASTER ─────────────────────────────────────────────────────
	stripMaster = {
		var titulo, lFader, fader, medL, medR, btnMute, lblRec, filaRec,
		    btnGuardar, btnCargar, contenedor;

		titulo = StaticText().string_("MASTER").align_(\center)
			.font_(fuenteTitulo).stringColor_(colAcento);

		// —— Osciloscopio: la forma de onda que sale por las bocinas ——
		// (post-fader master y post-limitador; L verde, R azul).
		~vistaScope = ScopeView()
			.server_(s)
			.bufnum_(~scopeBuf.index)
			.style_(1)                        // canales superpuestos
			.waveColors_([colVerde, colAzul])
			.background_(colFondo)
			.fixedHeight_(96).minWidth_(150)
			.canFocus_(false)
			.toolTip_("Forma de onda de la salida master, en vivo\n(post-limitador). Verde = L, azul = R.");

		lFader = StaticText().string_("0.0dB").align_(\center)
			.font_(fuentePeq).stringColor_(colTexto);

		fader = Slider()
			.maxWidth_(~cfg[\anchoFader]).minHeight_(160)
			.toolTip_("Fader general de la mezcla (antes del limitador).\n(Doble click: escribir el valor en dB a mano.)")
			.value_(specFader.unmap(0))
			.action_({ |sl|
				var db  = specFader.map(sl.value);
				var amp = if(db <= -59.5) { 0 } { db.dbamp };
				lFader.string = if(db <= -59.5) { "-inf" } { db.round(0.1).asString ++ "dB" };
				~sintMaster.set(\amp, amp);
			});
		fader.mouseDownAction = { |view, x, y, mods, boton, clicks|
			if(clicks == 2) {
				~pideValor.("FADER MASTER", specFader, specFader.map(fader.value),
					{ |v| fader.valueAction_(specFader.unmap(v)) });
			};
		};
		~faderMaster = fader;

		medL = LevelIndicator().maxWidth_(~cfg[\anchoMedidor]).minHeight_(160)
			.warning_(0.85).critical_(0.97).drawsPeak_(true)
			.toolTip_("Salida izquierda (post-limitador).");
		medR = LevelIndicator().maxWidth_(~cfg[\anchoMedidor]).minHeight_(160)
			.warning_(0.85).critical_(0.97).drawsPeak_(true)
			.toolTip_("Salida derecha (post-limitador).");
		~medidores[numCanales]     = medL;
		~medidores[numCanales + 1] = medR;

		btnMute = Button()
			.states_([["MUTE", colTexto, colStripMaster], ["MUTE", Color.white, colRojo]])
			.font_(fuente).maxHeight_(22)
			.toolTip_("Silencia la salida general.")
			.action_({ |b| ~sintMaster.set(\mute, 1 - b.value) });

		lblRec = StaticText().string_("").align_(\center)
			.font_(fuentePeq).stringColor_(colTextoSuave);

		// Checkbox STEMS: elige entre grabar la mezcla estéreo (apagado) o
		// 3 WAVs separados, uno por canal, post-fader (encendido).
		~chkStems = CheckBox()
			.toolTip_("Apagado: graba la mezcla estéreo tal como la escuchas.\nEncendido: graba 3 WAVs separados, uno por canal (post-fader,\nsin pan) — ideales para mezclar después en un DAW.");

		~btnRec = Button()
			.states_([["● REC", colRojo, colStripMaster], ["■ STOP", Color.white, colRojo]])
			.font_(fuente).maxHeight_(24)
			.toolTip_("Graba a WAV 24-bit en ./" ++ ~cfg[\carpetaRec] ++ "/ junto a este archivo.\nCon [stems] apagado: la mezcla estéreo (al detener se carga sola\nen el reproductor). Con [stems] encendido: un WAV por canal.")
			.action_({ |b|
				if(b.value == 1) {
					// El modo se decide al ARRANCAR y no se puede cambiar
					// a media grabación (por eso se desactiva el checkbox).
					~grabandoStems = ~chkStems.value;
					~chkStems.enabled = false;
					if(~grabandoStems) {
						~iniciaStems.value;
						lblRec.string = "grabando stems…";
					} {
						// Nombre con fecha y hora: sesion_AAMMDD_HHMMSS.wav
						~rutaUltimaGrabacion = ~dirGrabaciones +/+
							("sesion_" ++ Date.getDate.stamp ++ ".wav");
						s.record(~rutaUltimaGrabacion, numChannels: 2);
						lblRec.string = "grabando…";
					};
					~ledNota.(~cfg[\notaRec], true);
				} {
					if(~grabandoStems) {
						~detieneStems.value;
						lblRec.string = "3 stems → ./" ++ ~cfg[\carpetaRec] ++ "/";
					} {
						s.stopRecording;
						lblRec.string = PathName(~rutaUltimaGrabacion).fileName;
						// Esperamos 1 s a que el servidor cierre el archivo
						// antes de cargarlo al reproductor.
						SystemClock.sched(1.0, {
							~cargarEnPlayer.(~rutaUltimaGrabacion);
							nil   // (regresar nil = no repetir la tarea)
						});
					};
					~chkStems.enabled = true;
					~ledNota.(~cfg[\notaRec], false);
				};
			});

		filaRec = HLayout(
			[~btnRec, stretch: 1],
			VLayout(
				[~chkStems, align: \center],
				StaticText().string_("stems").align_(\center)
					.font_(fuentePeq).stringColor_(colTextoSuave)
			).spacing_(0)
		).spacing_(4);

		btnGuardar = Button()
			.states_([["GUARDAR PRESET", colTexto, colStripMaster]])
			.font_(fuentePeq).maxHeight_(20)
			.toolTip_("Guarda en un archivo todos los valores actuales:\nperillas, procesadores encendidos y faders.")
			.action_({ ~guardarPreset.value });

		btnCargar = Button()
			.states_([["CARGAR PRESET", colTexto, colStripMaster]])
			.font_(fuentePeq).maxHeight_(20)
			.toolTip_("Restaura la mezcladora desde un preset guardado.")
			.action_({ ~cargarPreset.value });

		contenedor = View().background_(colStripMaster);
		contenedor.layout = VLayout(
			titulo,
			~vistaScope,
			nil,   // espacio elástico
			lFader,
			[HLayout([fader, align: \center], [medL, align: \center], [medR, align: \center]).spacing_(4), stretch: 1],
			btnMute,
			filaRec,
			lblRec,
			btnGuardar,
			btnCargar
		).margins_(7).spacing_(4);

		contenedor
	}.value;

	// ── Fila del REPRODUCTOR (parte inferior) ────────────────────────────────
	filaPlayer = {
		var tituloP, btnAbrir, contenedor, layoutVol;

		tituloP = StaticText().string_("REPRODUCTOR").font_(fuentePeq)
			.stringColor_(colTextoSuave);

		~lblArchivo = StaticText().string_("— sin archivo — (graba una sesión o abre un WAV)")
			.font_(fuente).stringColor_(colTexto);

		~lblTiempo = StaticText().string_("0:00 / 0:00").align_(\center)
			.font_(fuente).stringColor_(colAcento).fixedWidth_(90);

		// Forma de onda del archivo cargado, con línea de posición en vivo.
		~vistaOnda = SoundFileView()
			.background_(colFondo)
			.gridOn_(false)
			.timeCursorOn_(true)
			.timeCursorColor_(colAcento)
			.peakColor_(colVerde)
			.rmsColor_(Color.new255(170, 220, 170))
			.fixedHeight_(56)
			.canFocus_(false)
			.toolTip_("Forma de onda del archivo cargado; la línea marca la posición.\nClick: saltar a ese punto (también durante la reproducción).");
		~vistaOnda.mouseUpAction = { |v|
			if(~rutaPlayer.notNil) { ~saltarA.(v.selection(0)[0]) };
		};

		~btnPlay = Button()
			.states_([["▶ PLAY", colVerde, colStrip], ["■ STOP", Color.black, colVerde]])
			.font_(fuente).fixedWidth_(80).maxHeight_(26)
			.toolTip_("Reproduce el archivo cargado hacia el destino elegido\na la derecha (siempre pasa por el limitador del master).")
			.enabled_(false)
			.action_({ |b|
				if(b.value == 1) {
					if(~rutaPlayer.notNil) { ~iniciarPlayer.value } { b.value = 0 };
				} {
					~detenerPlayer.value;
				};
			});

		~btnLoop = Button()
			.states_([["LOOP", colTextoSuave, colStrip], ["LOOP", Color.black, colAzul]])
			.font_(fuentePeq).fixedWidth_(52).maxHeight_(26)
			.toolTip_("Repite el archivo sin cortes al llegar al final\n(regresa al punto de arranque). Se puede prender\ny apagar durante la reproducción.")
			.action_({ |b|
				~loopPlayer = (b.value == 1);
				~sintPlayer !? { ~sintPlayer.set(\loop, b.value) };
			});

		// Destino del reproductor: directo al master, o a la CADENA de un
		// canal — el audio entra antes del EQ y pasa por todo (EQ, dist,
		// comp, pitch, fader, envíos), sumándose a lo del micrófono.
		~menuDest = PopUpMenu()
			.items_(["→ MASTER"] ++ numCanales.collect { |i|
				"→ " ++ ~nombreCortoCanal.(i).toUpper })
			.font_(fuentePeq).fixedWidth_(110)
			.toolTip_("A dónde va el reproductor:\nMASTER = directo a la salida, sin procesar.\nUn canal = entra a su cadena completa (EQ, distorsión,\ncompresor, pitch y envíos) — ideal para probar los efectos\ncon un audio grabado. Se puede cambiar mientras suena.")
			.action_({ |m|
				~destPlayer = m.value;
				// Si está sonando, re-arranca en el nuevo destino desde la
				// posición actual (mismo mecanismo que el click en la onda).
				~sintPlayer !? {
					~saltarA.((~tiempoPlayer * ~srArchivo).asInteger);
				};
			});

		btnAbrir = Button()
			.states_([["ABRIR…", colTexto, colStrip]])
			.font_(fuentePeq).fixedWidth_(70).maxHeight_(26)
			.toolTip_("Abre cualquier archivo de audio del disco\n(tus sesiones grabadas, material de referencia, etc.).")
			.action_({ Dialog.openPanel({ |ruta| ~cargarEnPlayer.(ruta) }) });

		layoutVol = hazKnob.(nil, nil, "VOL",
			"Volumen del reproductor.",
			specVolPlayer, 0, { |v|
				~ampPlayer = if(v <= -39.5) { 0 } { v.dbamp };
				~sintPlayer !? { ~sintPlayer.set(\amp, ~ampPlayer) };
			});

		contenedor = View().background_(colStrip);
		contenedor.layout = VLayout(
			~vistaOnda,
			HLayout(
				tituloP,
				[~lblArchivo, stretch: 1],
				~btnPlay,
				~btnLoop,
				~menuDest,
				~lblTiempo,
				layoutVol,
				btnAbrir
			).spacing_(8)
		).margins_(7).spacing_(4);

		contenedor
	}.value;

	// ── Fila de PRESETS RÁPIDOS (slots) ──────────────────────────────────────
	// Un botón por slot: click carga; con [GUARDAR EN…] armado, click guarda.
	// Cada slot también se carga con su nota MIDI (fila baja del X-Touch).
	filaSlots = {
		var lbl, contenedor;

		lbl = StaticText().string_("PRESETS RÁPIDOS").font_(fuentePeq)
			.stringColor_(colTextoSuave);

		~btnsSlot = ~numSlots.collect { |n|
			Button().font_(fuente).fixedWidth_(36).maxHeight_(26)
				.toolTip_("Preset rápido " ++ (n + 1) ++ ": click = cargar.\nCon [GUARDAR EN…] armado, click = guardar aquí el estado actual.\nTambién se carga con la nota MIDI " ++ ~cfg[\notasSlots][n] ++ "\n(fila baja del X-Touch Mini).")
				.action_({
					if(~modoGuardarSlot) { ~guardarSlot.(n) } { ~cargarSlot.(n) };
				});
		};

		~btnGuardarEn = Button()
			.states_([["GUARDAR EN…", colTexto, colStrip], ["ELIGE SLOT…", Color.white, colRojo]])
			.font_(fuentePeq).fixedWidth_(92).maxHeight_(26)
			.toolTip_("Arma el modo guardar: el siguiente slot que presiones\nguardará el estado actual completo de la mezcladora.\nVuelve a presionar para cancelar.")
			.action_({ |b| ~modoGuardarSlot = (b.value == 1) });

		// Pinta los botones según su estado: vacío (apagado), ocupado
		// (relieve claro) o activo (acento). También refleja la ocupación
		// en los LEDs de la fila baja del controlador.
		~pintaSlots = {
			~numSlots.do { |n|
				var lleno = ~slots[n].notNil;
				~btnsSlot[n].states_([[
					(n + 1).asString,
					case { n == ~slotActivo } { Color.black }
					     { lleno }            { colTexto }
					     { true }             { colTextoSuave },
					case { n == ~slotActivo } { colAcento }
					     { lleno }            { Color.new255(48, 50, 60) }
					     { true }             { colStrip }
				]]);
			};
			~numSlots.do { |n| ~ledNota.(~cfg[\notasSlots][n], ~slots[n].notNil) };
		};
		~pintaSlots.value;

		contenedor = View().background_(colStrip);
		contenedor.layout = HLayout(
			*([lbl] ++ ~btnsSlot ++ [nil, ~btnGuardarEn])
		).margins_(7).spacing_(4);

		contenedor
	}.value;

	// ── Fila del TÍTULO + estado MIDI ────────────────────────────────────────
	~mapaActivo = 0;
	~textoMapa = {
		~mapasMIDI[~mapaActivo][\nombre]
		++ "  (" ++ (~mapaActivo + 1) ++ "/" ++ ~mapasMIDI.size ++ ")"
	};
	~lblMapa = StaticText().string_(~textoMapa.value)
		.font_(fuente).stringColor_(colVerde).align_(\right).fixedWidth_(140);
	~cambiarMapa = {
		~mapaActivo = (~mapaActivo + 1) % ~mapasMIDI.size;
		~lblMapa.string = ~textoMapa.value;
		// Al cambiar de banco, los anillos del controlador deben mostrar
		// los valores de los NUEVOS destinos:
		~refrescaLEDs.value;
		("Mapa MIDI activo: " ++ ~mapasMIDI[~mapaActivo][\nombre]).postln;
	};

	btnMapa = Button()
		.states_([["MAPA →", colTexto, colStrip]])
		.font_(fuentePeq).fixedWidth_(64).maxHeight_(20)
		.toolTip_("Cicla entre los mapas MIDI definidos en la configuración.\nTambién puedes ciclarlos con la nota MIDI configurada\n(botón " ++ ~cfg[\notaCambiarMapa] ++ " del X-Touch Mini).")
		.action_({ ~cambiarMapa.value });

	filaTitulo = HLayout(
		StaticText().string_(~cfg[\titulo].toUpper)
			.font_(fuenteApp).stringColor_(colAcento),
		nil,
		StaticText().string_("MAPA MIDI:").font_(fuentePeq).stringColor_(colTextoSuave),
		~lblMapa,
		btnMapa
	).spacing_(6);

	// ── Ventana principal ────────────────────────────────────────────────────
	ventana = Window(~cfg[\titulo],
		Rect(~cfg[\ventanaX], ~cfg[\ventanaY], ~cfg[\ventanaAncho], ~cfg[\ventanaAlto]))
		.background_(colFondo);

	ventana.layout = VLayout(
		filaTitulo,
		// HLayout(*array): el asterisco desempaca el arreglo como argumentos.
		[HLayout(*(numCanales.collect { |i| hazStrip.(i) } ++ [stripFx, stripMaster])).spacing_(6), stretch: 1],
		filaSlots,
		filaPlayer
	).margins_(8).spacing_(6);

	// ═══════════════════════════════════════════════════════════════════════
	// 7. MIDI — mapas por bancos (configurados en la sección 0)
	// ═══════════════════════════════════════════════════════════════════════
	// Un CC entrante se busca en el mapa ACTIVO; su destino se aplica con
	// valueAction_ sobre el mismo control de la GUI → perilla, curva de EQ,
	// synth y presets quedan sincronizados, muevas lo que muevas.

	~aplicaMIDI = { |dest, v01|
		{	// La GUI solo puede tocarse desde su hilo: por eso { }.defer
			switch(dest[0],
				\perilla, {
					var e = ~reg[dest[1]][dest[2]];
					e !? { e[\knob].valueAction_(v01) };
				},
				\fader,  { ~faders[dest[1]].valueAction_(v01) },
				\master, { ~faderMaster.valueAction_(v01) },
				\fx,     {
					var e = ~regFx[dest[1]];
					e !? { e[\knob].valueAction_(v01) };
				}
			);
		}.defer;
	};

	// ── LEDs del controlador (X-Touch Mini) ─────────────────────────────────
	// En modo estándar, el X-Touch enciende el LED de un botón al recibir
	// la MISMA nota de vuelta (velocity 127 = on, 0 = off), y el anillo de
	// un encoder sigue al MISMO CC de vuelta (valor 0..127), todo por el
	// canal configurado en la sección 0. Si no hay ~midiOut, no hacen nada.
	~ledNota = { |nota, encendido|
		~midiOut !? {
			~midiOut.noteOn(~cfg[\midiCanalLeds], nota, if(encendido) { 127 } { 0 });
		};
	};

	// Manda al controlador el estado actual: anillos de los encoders según
	// los destinos del mapa ACTIVO + LEDs de mute, REC y slots. Se llama al
	// cambiar de mapa, al aplicar un estado (slots/presets) y al conectar.
	~refrescaLEDs = {
		~midiOut !? {
			~mapasMIDI[~mapaActivo][\ccs].keysValuesDo { |cc, dest|
				var v01 = switch(dest[0],
					\perilla, {
						var e = ~reg[dest[1]][dest[2]];
						e !? { e[\knob].value };
					},
					\fader,  { ~faders[dest[1]].value },
					\master, { ~faderMaster.value },
					\fx,     {
						var e = ~regFx[dest[1]];
						e !? { e[\knob].value };
					}
				);
				v01 !? {
					~midiOut.control(~cfg[\midiCanalLeds], cc, (v01 * 127).round.asInteger);
				};
			};
			numCanales.do { |i|
				~cfg[\notasMute][i] !? { |n| ~ledNota.(n, ~btnsMute[i].value == 1) };
			};
			~ledNota.(~cfg[\notaRec], ~btnRec.value == 1);
			~numSlots.do { |n| ~ledNota.(~cfg[\notasSlots][n], ~slots[n].notNil) };
		};
	};

	if(~cfg[\midiHabilitado]) {
		try {
			if(MIDIClient.initialized.not) { MIDIClient.init };
			MIDIIn.connectAll;

			// Salida hacia el controlador, para los LEDs: se busca por
			// nombre entre los destinos MIDI. Si no está conectado, se
			// sigue sin retroalimentación (y sin errores).
			~destinoLeds = MIDIClient.destinations.detect { |e|
				e.device.asString.containsi(~cfg[\midiNombreControlador]) or: {
					e.name.asString.containsi(~cfg[\midiNombreControlador])
				}
			};
			~destinoLeds !? {
				~midiOut = MIDIOut.newByName(~destinoLeds.device, ~destinoLeds.name)
					.latency_(0);
				("✓ LEDs del controlador: " ++ ~destinoLeds.device).postln;
				~refrescaLEDs.value;
			};

			MIDIdef.cc(\vozCC, { |val, num|
				var dest = ~mapasMIDI[~mapaActivo][\ccs][num];
				dest !? { ~aplicaMIDI.(dest, val / 127) };
			});

			MIDIdef.noteOn(\vozNotas, { |vel, num|
				var idx;
				case
				{ num == ~cfg[\notaCambiarMapa] } {
					{ ~cambiarMapa.value }.defer
				}
				{ (idx = ~cfg[\notasMute].indexOf(num)).notNil and: { idx < numCanales } } {
					{ ~btnsMute[idx].valueAction_(1 - ~btnsMute[idx].value) }.defer
				}
				{ num == ~cfg[\notaRec] } {
					{ ~btnRec.valueAction_(1 - ~btnRec.value) }.defer
				}
				{ (idx = ~cfg[\notasSlots].indexOf(num)).notNil } {
					{ ~cargarSlot.(idx) }.defer
				};
			});

			"✓ MIDI listo: conecta el controlador y mueve perillas.".postln;
		} { |err|
			("⚠ MIDI no disponible: " ++ err.errorString).postln;
			{ ~lblMapa.string = "MIDI no disponible" }.defer;
		};
	} {
		~lblMapa.string = "MIDI desactivado";
	};

	// ═══════════════════════════════════════════════════════════════════════
	// 8. MEDIDORES (mensajes OSC del servidor → GUI)
	// ═══════════════════════════════════════════════════════════════════════
	// SendPeakRMS manda: [ '/ruta', nodeID, idMedidor, pico, rms ]
	// (para estéreo agrega pico2 y rms2). Amplitud → dB → 0..1 con linlin,
	// usando -60 dB como piso visual del medidor.

	OSCdef(\medidorCanal, { |msg|
		var id = msg[2], pico = msg[3], rms = msg[4];
		{	// La GUI solo puede tocarse desde su hilo: por eso { }.defer
			if(~medidores[id].notNil) {
				~medidores[id].value     = rms.ampdb.linlin(-60, 0, 0, 1);
				~medidores[id].peakLevel = pico.ampdb.linlin(-60, 0, 0, 1);
			};
		}.defer;
	}, '/medidorCanal');

	OSCdef(\medidorMaster, { |msg|
		var picoL = msg[3], rmsL = msg[4], picoR = msg[5], rmsR = msg[6];
		{
			~medidores[numCanales].value         = rmsL.ampdb.linlin(-60, 0, 0, 1);
			~medidores[numCanales].peakLevel     = picoL.ampdb.linlin(-60, 0, 0, 1);
			~medidores[numCanales + 1].value     = rmsR.ampdb.linlin(-60, 0, 0, 1);
			~medidores[numCanales + 1].peakLevel = picoR.ampdb.linlin(-60, 0, 0, 1);
		}.defer;
	}, '/medidorMaster');

	// ═══════════════════════════════════════════════════════════════════════
	// 9. LIMPIEZA al cerrar la ventana
	// ═══════════════════════════════════════════════════════════════════════
	ventana.onClose = {
		if(s.isRecording) { s.stopRecording };
		if(~sintsStem.notNil) { ~detieneStems.value };
		~detenerPlayer.value;
		try { ~vistaScope.stop };
		[~gEntradas, ~gFx, ~gSalidas, ~gGrab, ~gFxGlobal, ~gPlayer, ~gMaster].do(_.free);
		~busCanal.do(_.free);
		~busGrab.do(_.free);
		[~busRev, ~busDel].do(_.free);
		~scopeBuf.free;
		// Apagar todos los LEDs del controlador al salir:
		~midiOut !? { (0..23).do { |n| ~midiOut.noteOn(~cfg[\midiCanalLeds], n, 0) } };
		OSCdef(\medidorCanal).free;
		OSCdef(\medidorMaster).free;
		MIDIdef(\vozCC).free;
		MIDIdef(\vozNotas).free;
		"Mezcladora cerrada: nodos, buses, OSCdefs y MIDIdefs liberados.".postln;
	};

	ventana.front;
	~vistaScope.start;   // el scope arranca cuando la ventana ya existe
	("✓ " ++ ~cfg[\titulo] ++ " v5 lista: EQ con curva · dist · comp · pitch · reverb/delay por envíos · player con loop y ruteo a canal · presets rápidos · stems · MIDI+LEDs · rec → ./" ++ ~cfg[\carpetaRec] ++ "/").postln;
});
)


/*
================================================================================
  CÓMO SEGUIR EXTENDIENDO LA CADENA
================================================================================
El pitch shifter que antes vivía aquí como ejemplo ya está integrado al patch
(sección PITCH de cada canal). Para agregar un efecto NUEVO, el patrón sigue
siendo el mismo de siempre:

  1. SynthDef que LEE el bus con In.ar y lo SOBREESCRIBE con ReplaceOut.ar,
     con un parámetro \on para el bypass (copia \ins_dist o \ins_pitch).
  2. Instancia con Synth.tail(~gFxCanal[i], ...) en la sección 4 → se
     inserta al final de la cadena de ese canal. El ORDEN de creación de
     los synths dentro del grupo ES el orden de procesamiento.
  3. Pásale \bus, ~busCanal[i].
  4. En hazStrip copia el patrón de la sección PITCH: hazSeccion (botón ON)
     + hazKnob con registro en ~reg. Con eso el RESET, los PRESETS y los
     MAPAS MIDI lo incluyen automáticamente (solo agrega su clave a los
     mapas de la sección 0 si quieres controlarlo desde el controlador).

(El reverb y el delay ya existen, pero como efectos de ENVÍO globales —
sección 3f-bis y columna FX. Para un efecto de envío nuevo, copia ese otro
patrón: bus de envío + perilla send en \ent_salidaCanal + retorno en
~gFxGlobal.) Ideas naturales como insert: un ring modulator para la voz,
un bitcrusher para la boca, un freeze granular para la garganta.
================================================================================
*/
