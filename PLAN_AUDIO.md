# Plan de audio — GatitoAI

## Dirección
Cozy japonés, íntimo y natural: la isla respira y la música deja espacio.
Sin sonidos estridentes, sobresaltos ni un efecto por cada decisión del cerebro.
Estado: fase A inicial integrada con oleaje, brisa y grillos generados. Música y SFX siguen pendientes.
La escucha y el ajuste final de mezcla los realizará el usuario.

## 1. Paisaje sonoro por capas

### Mar, siempre presente
- Cama estéreo suave de oleaje, continua y sin golpes graves exagerados.
- Rompientes independientes, espaciadas y variadas; espuma que se retira sobre arena.
- Más presencia cerca de la orilla; desde el centro queda como fondo lejano.
- No duplicar un bucle por cada casilla: una cama y pocas fuentes costeras.
- Evitar sincronizar cada ola visual con un sonido: sincronizar solo eventos destacados.

### Día
- Brisa entre hojas y bambú, con ráfagas suaves.
- Pájaros lejanos ocasionales; cigarras muy discretas y no constantes.
- Sin gaviotas insistentes ni insectos agudos ocupando toda la mezcla.

### Atardecer
- Reducir aves/cigarras y abrir gradualmente espacio a los grillos.
- Mantener el mar como continuidad entre ambas escenas sonoras.
- No cortar capas exactamente al cambiar el nombre de la fase horaria.

### Noche cozy
- Grillos suaves, distribuidos con pausas; brisa y mar más perceptibles, no necesariamente más fuertes.
- Hojas aisladas y algún crujido de bambú cercano, sin estética de terror.
- Faroles: un pequeño encendido y, solo muy cerca, crepitar casi imperceptible.
- Una vela pequeña NO debe sonar como una hoguera.
- Transiciones progresivas guiadas por el mismo ciclo día/noche que las luces.

## 2. Música chill
- Instrumental original o con licencia comprobada, sin voces.
- Paleta: koto de pulsación suave, piano/fieltro, flauta aireada y texturas cálidas.
- Ritmo orientativo: 55–75 BPM, poca percusión, sin graves dominantes.
- No convertirlo en una caricatura musical japonesa ni en un beat constante.
- Día: pieza cálida y curiosa, 3–4 minutos.
- Noche: pieza más espaciada e íntima, 3–4 minutos, menos notas y menos percusión.
- Menú: reutilizar un fragmento tranquilo al principio; tema propio más adelante.
- Reproducir piezas con silencios entre ellas (45–120 s orientativos).
- Cambiar de pieza en un cierre musical o con fundido largo; evitar dos melodías superpuestas.
- Una pieza no debe acelerarse ni cambiar de tono por usar x4/x10.
- Fuente pendiente: composición original, aportación del usuario o biblioteca licenciada.
	La generación de efectos sonoros no se presupone como generador de música.

## 3. SFX prioritarios

| Familia | Sonidos | Variantes / criterio |
|---|---|---|
| Interfaz | pulsar, volver, entrar a la isla | 2–3 suaves; sin sonido al pasar por cada opción |
| Gato | maullido curioso, petición, alegría, molestia leve | 2–3 por emoción; solo eventos relevantes |
| Descanso | ronroneo y respiración suave | cerca del gato; intermitente, no un ronquido cómico constante |
| Patas | arena, hierba, madera/tatami | 3–4 por superficie; solo al desplazarse realmente |
| Comida | mordisco y masticación de pescado | 2–3; estilizado, sin sonidos húmedos fuertes |
| Exploración | olfateo, escarbar arena/tierra | olfateo raro; escarbar acompaña el gesto |
| Juego | golpe de temari, roce de concha, rascado | 2–4; según material |
| Descubrimiento | cascabel suzu, aparición de objeto | suzu físico; evitar fanfarria de recompensa |
| Cangrejo | pasos/clic de pinzas y reacción de pellizco | breve y simpático, nunca un sobresalto |
| Refugio | apoyo sobre tatami, roce de madera | muy discretos |
| Faroles | encendido, apagado y crepitar mínimo | activar al cruzar umbrales con histéresis, no cada fotograma |

No sonorizar cada globo de texto. Maullidos con un intervalo mínimo y probabilidad moderada.
Un cambio de pose repetido no debe reiniciar un bucle ni disparar otro maullido.
Los pasos deben seguir la animación y el desplazamiento, no el número de decisiones de IA.

## 4. Mezcla y comportamiento técnico propuestos
- Buses: Master, Música, Ambiente y SFX; voces del gato dentro de SFX inicialmente.
- Controles independientes de volumen y silencio total; conservar preferencias.
- Valores de arranque orientativos: Música −22 dB, Ambiente −18 dB, SFX −12 dB.
	Son niveles de bus sobre archivos previamente nivelados: ajustar escuchando, no valores finales.
- El mar no debe ocultar al gato; tampoco un maullido debe tapar la isla.
- Posicionamiento con panorámica moderada: el isométrico no necesita extremos estéreo.
- Vista panorámica: reducir detalle cercano y evitar sumar todos los sonidos de la isla.
- Seguir al gato: escuchar detalles locales. Mover la cámara debe cambiar las distancias con suavidad.
- Limitar voces simultáneas y agrupar pasos/insectos; pequeñas variaciones de volumen y tono en SFX.
- A x4/x10: mantener tono/velocidad de música y camas ambientales, limitar eventos por tiempo real.
	Evitar diez maullidos o diez pasos superpuestos por segundo al acelerar la simulación.
- Fundidos al entrar, salir y cambiar de ambiente. Sin clics ni cortes de bucle.
- OGG para música/ambientes largos; WAV corto para SFX cuando convenga.
- Registrar autor, licencia y procedencia de cada recurso antes de publicar.

## 5. Orden de implementación

### Fase A — La isla respira
- [x] Buses y controles de volumen/mute persistentes (`user://audio_settings.cfg`).
- [~] Oleaje base, brisa y grillos nocturnos en bucle; pendiente escuchar continuidad y balance.
- [x] Transición día/noche conectada al ciclo de iluminación, fades en tiempo real.
- [x] Test dev Día/Noche: volumen, mute, aislamiento de buses y de mar/brisa/grillos.

### Fase B — El gato tiene presencia
- [ ] Pasos por superficie, escarbar, comer, ronroneo y cuatro familias de maullidos.
- [ ] Temari, rascador, cascabel, concha y cangrejo.
- [ ] Límites de repetición; validar a x1/x4/x10.

### Fase C — Música y pulido
- [ ] Seleccionar/producir una pieza diurna y otra nocturna con licencia válida.
- [ ] Silencios entre piezas, entradas suaves y transición sin choque musical.
- [ ] Sonidos de menú y entrada a la isla.
- [ ] Afinar mezcla en auriculares y altavoces pequeños, de día y de noche.

## 6. Criterios de aceptación
- Escuchar cinco minutos sin sentir un bucle evidente ni sonidos molestos repetidos.
- Poder reconocer día, noche y cercanía al mar sin mirar la pantalla.
- La música acompaña, no ocupa todos los momentos ni cambia de tono al acelerar.
- El botón dev Día/Noche cambia luces y ambiente de forma coherente, sin disparar muchos encendidos.
- x10 no satura voces; silenciar cada categoría funciona de forma independiente.
- El audio expresa acciones físicas reales; no añade reglas nuevas a la IA experimental.
- No hay clipping, cortes de bucle ni recursos sin procedencia/licencia registrada.

## Entrega A — Cómo probar
- F5: menú e isla con ambiente. Panel Audio abajo a la derecha.
- Abrir tests/dev_day_night.tscn y pulsar F6: Opciones de audio permite aislar cada capa.
- Los grillos entran gradualmente de noche. A x10 no se acelera el tono de las camas.
- La escucha de continuidad, intensidad y naturalidad queda pendiente del usuario.
- Esta primera cama es global: proximidad a la costa y detalles espaciales siguen pendientes.
- Cambio menú/juego: las camas reinician; aún falta fundido de salida/continuidad entre escenas.
- 18 pruebas aprobadas; ejecución dev con controles y cambio nocturno sin errores.
- No hay música ni SFX del gato todavía; no iniciar fase B hasta revisar esta mezcla.
