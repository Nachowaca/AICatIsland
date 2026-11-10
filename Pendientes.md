# GatitoAI — Pendientes

Concepto: isla isométrica del Japón antiguo con entorno principalmente procedural; gato y chōchin con sprites IA.
Un gatito vive solo: pocas pautas simples, y él descubre, aprende y evoluciona.

Leyenda: `[x]` hecho · `[~]` en curso / versión 1 · `[ ]` pendiente

---

## 0. Hecho hasta ahora
- [x] Isla procedural isométrica (arena, hierba, musgo) con estilo de grabado ukiyo-e
- [x] Árboles japoneses: sakura, momiji, pino niwaki, bambú (copas tipo nube)
- [x] Mar con shader: profundidad, olas hacia la costa, espuma, cáusticas, reflejos, destellos
- [x] Playas reales: costa suave e irregular (campo de distancia + ruido), anchos de 1 a 4 celdas,
      tramos de acantilado de pasto, arena a nivel del mar con ondas, guijarros y banda mojada
- [x] Oleaje sobre la playa: el agua sube y se retira al ritmo de las crestas, con espuma
      en el frente, burbujas y encaje que queda en la arena
- [x] Vida de playa (`shore_decor.gd`): rocas con anillos de espuma, algas, maderas, conchas y estrellas de mar
- [x] El gato baja y sube el talud de pasto suavemente; pesca desde la orilla real
- [x] Pasto irregular estilo grabado: manchas de color suaves, borde festoneado sobre la arena,
      matas, susuki, flores (nadeshiko, kikyō…) y trébol meciéndose con viento y ráfagas (`meadow.gd` + `grass_sway.gdshader`)
- [x] Ciclo día/noche (4 min): atardecer cálido, ambiente lunar frío y encendido/apagado suave de velas
- [x] Dos chōchin (rojo y crema con crisantemo) basados en referencia, soportes de madera y luz ámbar con parpadeo
- [ ] Sol y luna visibles, recorrido celeste y sombras que acompañen su dirección
- [x] Objetos: santuario, 2 chōchin de vela, rascador, temari, torii en el agua
- [x] Pescado en la orilla (aparece solo, más al amanecer; clic para dejar uno)
- [x] IA de utilidad + aprendizaje simple + memoria de pesca + personalidad que deriva
- [x] Cerebro persistente entre sesiones (`user://gatito_brain.json`)
- [x] HUD compacto y plegable (H oculta), cámara que sigue al gato, velocidades x1/x4/x10
- [x] Pruebas automáticas de la IA (`res://tests/test_cat_ai.gd`, 7 pruebas)
- [x] Gato naranja atigrado con sprites IA: caminar, reposar, dormir, comer, jugar, escarbar y acicalarse
- [x] Atlas limpios y reducidos a celdas de 112×112, sombra y globos sobre el personaje
- [ ] Direcciones traseras isométricas del gato (actualmente espejo horizontal de una vista 3/4)
- [ ] Animaciones propias de rascar y revolcarse (ahora reutilizan juego); loaf reutiliza dormir
- [ ] Pulir continuidad entre fotogramas y revisar todas las poses en movimiento

## 1. Descubrir solo (sin saber de antemano)
Idea: el MUNDO define qué hace cada cosa; el gato no lo sabe y lo aprende probando.
Código: `scripts/world/discoverable.gd` (leyes del mundo) y `_best_interaction()` / `_learn_interaction()` en `scripts/cat/cat.gd`.
Medido (5 gatos, 2 días): prueban 18–25 combinaciones, el 1er hallazgo llega entre 70 s y 4 min, y cada uno acaba con favoritos distintos.
- [x] Verbos básicos que el gato puede intentar con cualquier cosa:
      olfatear, escarbar, dar zarpazos, morder, tumbarse
- [x] Aprende el efecto real de cada (cosa + verbo) sobre sus necesidades
- [x] Curiosidad: lo que nunca probó le atrae (más si es curioso o está aburrido)
- [x] Generaliza por tipo: lo aprendido con un montículo vale para otros montículos
- [~] Cerebro v2 experimental activo: verbos sin utilidades prefijadas, efectos netos aprendidos, percepción local, memoria por lugar/contexto y parámetros libres (`FreeBrain`)
- [ ] Estudiar varias semillas y corregir sesgos del selector sin regalar soluciones
- [ ] Aprendizaje de secuencias, generalización perceptiva y costes reales de desplazamiento
- [ ] Experimento de los 5 gatos: comprobar que salen personalidades distintas
- [ ] Equilibrar: hoy la novedad gana mucho y la pelota/rascador casi no se usan
- [ ] Que también aprenda a evitar: recordar el pellizco del cangrejo con más fuerza (miedo)
- [ ] Combinar verbos (llevar el cascabel al santuario, enterrar cosas él mismo)

## 2. Objetos ocultos y secretos
- [x] Montículos en la arena/hierba → al escarbar aparece algo (concha, cascabel)
- [x] Concha: juguete para dar zarpazos
- [x] Cascabel (suzu) perdido: suena al tocarlo ♪
- [x] Roca de la orilla con cangrejo: sale si la tocas; se puede cazar… pero pellizca
- [x] Matatabi (planta que vuelve locos a los gatos): olfatearla = euforia
- [x] Hueco entre raíces del pino: guarida secreta, muy segura de noche
- [x] La marea vuelve a enterrar cosas al cambiar de día
- [ ] Luciérnagas (hotaru) junto al bambú solo en noches de verano
- [ ] Ofrendas (onigiri) que aparecen a veces en el santuario
- [ ] Pájaros / mariposas para perseguir
- [ ] Charca con carpas koi
- [ ] Objetos que llegan flotando a la costa (botellas, maderas)

## 3. Hablar / voz del gato
- [x] Frases según ánimo y necesidad más baja (contento, hambriento, con sueño, asustado, aburrido)
- [x] Reacciones a descubrimientos y a malas experiencias ("¡Ay, me pellizcó!")
- [x] Comentarios que recuerdan cosas aprendidas ("Me acuerdo del cascabel…")
- [ ] Maullidos con sonido (generados) según emoción
- [ ] Hablarle al gato (el jugador escribe) y que reaccione según su personalidad
- [ ] Opcional futuro: voz/diario con un modelo de lenguaje (Anthropic) — NO por ahora

## 4. Santuario / refugio
- [x] Santuario más grande con interior: tatami, cojín zabuton, pergamino, lámpara andon
- [x] El gato entra a descansar; el techo se vuelve translúcido para verlo dentro
- [ ] Que no atraviese paredes al caminar (obstáculos en el pathfinding)
- [ ] Puertas shōji que se abren/cierran según la hora
- [ ] Otros refugios: barca varada, cesta, casita de pescador

## 5. Mundo y ambiente
- [ ] Lluvia / tormentas que asustan (buscar techo)
- [ ] Estaciones (sakura en primavera, momiji en otoño, nieve en invierno)
- [x] Viento visible en la hierba (ráfagas que barren la isla)
- [ ] Viento también en bambú, árboles y noren
- [ ] Sonido ambiente (olas, cigarras de día, grillos de noche)
- [ ] Niebla al amanecer

## 6. Técnica / organización
- [ ] Medir FPS fuera del editor (en la pestaña Game integrada siempre marca ~30) y optimizar si hace falta
- [ ] Elegir otra semilla o tamaño de isla desde un menú (todo se recoloca solo salvo los objetos de la escena)
- [x] Repositorio en GitHub: https://github.com/Nachowaca/AICatIsland (README + .gitignore)
- [ ] Guardar también el estado del mundo (objetos descubiertos)
- [~] Panel experimental con semilla/ensayos; registro JSON local de los últimos 200 ensayos
- [ ] Comparador entre gatos y gráficas de necesidades en el tiempo
- [ ] Más pruebas: que aprenda X tras N días
- [x] Escena de vista ampliada para revisar arte: `res://tests/zoom_preview.tscn`

- [x] Test dev de iluminación con botón Día/Noche: `res://tests/dev_day_night.tscn` (F6); transición de 4 s y memoria aislada.

## Plan de audio
- [x] Dirección de SFX, música chill, mar y noche cozy: [PLAN_AUDIO.md](PLAN_AUDIO.md).
- [ ] Implementar por fases: ambiente → gato/objetos → música y mezcla.

- [~] Audio fase A inicial: mar, brisa y grillos, buses/volúmenes y test dev integrados; pendiente escucha del usuario. Ver PLAN_AUDIO.md.

- [x] Experimento: aprendizaje compartido por apariencia/verbo, sin conocimiento alimentario previo; manejo de observaciones saturadas.
- [x] Costa con 8 pescados iniciales, tope 12 y reposición cada 8 s; saciedad experimental configurable (6 min para gastar 100).
- [ ] Medir en vivo primera ingesta y alimentación sostenida en varias semillas, sin indicar dónde ir ni qué morder.

- [x] Sueño experimental separado del descanso: fatiga base de 8 horas de isla y umbral de energía <10; despertar a 85 y urgencias con histéresis.
- [x] Plan de textos por actividad y contexto: PLAN_TEXTOS_GATITO.md (sin implementar).
- [ ] Escoger un lugar seguro aprendido para dormir; interrupción general, memoria espacial de recursos y planes de varios pasos.
- [ ] Observar en vivo varias semillas: alimentación, sueño, necesidades críticas y bloqueo de sueño.
