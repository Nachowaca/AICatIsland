# GatitoAI — Pendientes

Concepto: isla isométrica del Japón antiguo, todo dibujado con código (sin assets).
Un gatito vive solo: pocas pautas simples, y él descubre, aprende y evoluciona.

Leyenda: `[x]` hecho · `[~]` en curso / versión 1 · `[ ]` pendiente

---

## 0. Hecho hasta ahora
- [x] Isla procedural isométrica (arena, hierba, musgo) con estilo de grabado ukiyo-e
- [x] Árboles japoneses: sakura, momiji, pino niwaki, bambú (copas tipo nube)
- [x] Mar con shader: profundidad, olas hacia la costa, espuma, cáusticas, reflejos, destellos
- [x] Playa más baja que la hierba + arena mojada
- [x] Ciclo día/noche (4 min) con faroles y luces nocturnas
- [x] Objetos: santuario, 2 faroles tōrō, rascador, temari, torii en el agua
- [x] Pescado en la orilla (aparece solo, más al amanecer; clic para dejar uno)
- [x] IA de utilidad + aprendizaje simple + memoria de pesca + personalidad que deriva
- [x] Cerebro persistente entre sesiones (`user://gatito_brain.json`)
- [x] HUD compacto y plegable (H oculta), cámara que sigue al gato, velocidades x1/x4/x10
- [x] Pruebas automáticas de la IA (`res://tests/test_cat_ai.gd`, 7 pruebas)

## 1. Descubrir solo (sin saber de antemano)
Idea: el MUNDO define qué hace cada cosa; el gato no lo sabe y lo aprende probando.
Código: `scripts/world/discoverable.gd` (leyes del mundo) y `_best_interaction()` / `_learn_interaction()` en `scripts/cat/cat.gd`.
Medido (5 gatos, 2 días): prueban 18–25 combinaciones, el 1er hallazgo llega entre 70 s y 4 min, y cada uno acaba con favoritos distintos.
- [x] Verbos básicos que el gato puede intentar con cualquier cosa:
      olfatear, escarbar, dar zarpazos, morder, tumbarse
- [x] Aprende el efecto real de cada (cosa + verbo) sobre sus necesidades
- [x] Curiosidad: lo que nunca probó le atrae (más si es curioso o está aburrido)
- [x] Generaliza por tipo: lo aprendido con un montículo vale para otros montículos
- [ ] Pasar TODAS las acciones fijas (comer, dormir, rascar...) a este sistema (cerebro v2)
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
- [ ] Viento visible en hierba y bambú
- [ ] Sonido ambiente (olas, cigarras de día, grillos de noche)
- [ ] Niebla al amanecer

## 6. Técnica / organización
- [ ] Guardar también el estado del mundo (objetos descubiertos)
- [ ] Panel de "experimento": comparar gatos, gráficas de necesidades en el tiempo
- [ ] Más pruebas: que aprenda X tras N días
