# Experimento de autonomía v1
	
	## Qué estamos probando
	No ordenar soluciones: ofrecer verbos y aprender qué cambia en el cuerpo después de usarlos.
	El modo está activo por defecto en `Cat.experimental_mode`. Desactivarlo devuelve el cerebro clásico.
	No se promete supervivencia, conciencia ni inteligencia general.
	
	## Variables libres
	Seleccionar `Entities/Cat/FreeBrain` en main.tscn y modificar en el Inspector:
	- `fatigue_minutes`: minutos de juego para gastar 100 de energía despierto (10). Desgaste gradual; caminar no añade el recargo clásico. Jugar y otros efectos del mundo sí pueden gastar energía adicional. A x10, diez minutos de juego duran uno real.
- `experiment_seed`: 0 elige una semilla; un entero fijo controla el RNG del selector.
	- `curiosity`: bonificación por ensayos poco conocidos (0.7 inicial).
	- `random_choice`: probabilidad de elegir otra opción, incluso conocida (0.15).
	- `learning_rate`: cuánto reemplaza la experiencia reciente a la anterior (0.35).
	- `perception_radius`: alcance local en celdas (5).
	- `travel_cost`: penalización estimada por distancia (0.035).
	- `trial_seconds`: duración máxima del ensayo, salvo eventos puntuales (6 s).
	- `need_weights`: importancia de cada necesidad (todas 1 inicialmente).
	En `Cat.needs` se pueden cambiar los niveles iniciales. No cambiar las claves.
	Los rasgos del cerebro clásico están inactivos: no inventamos personalidad nueva todavía.
	
	## Qué sigue escrito, inevitablemente
	- Cuerpo: hambre, fatiga, miedo nocturno, calor, recuperación al descansar y asearse.
	- Mundo: comer pescado nutre, los objetos tienen efectos físicos, refugio/luz reducen miedo.
	- Movimiento, navegación, seis verbos y una función de preferencia basada en necesidades.
	- Explorar lo poco probado tiene valor intrínseco programado; no equivale a voluntad humana.
	La selección NO consulta la tabla de efectos ni asocia necesidades a verbos de antemano.
	Solo considera posiciones percibidas y recordadas. Puede recordar un objeto que ya no está,
	viajar hasta allí y descubrir su ausencia. La navegación aún conoce la geometría de la isla.
	
	## Cómo aprende
	Memoria por objeto o zona de suelo de 3×3, verbo y contexto (día/noche, calor/fresco).
	Al terminar mide el cambio NETO de cada necesidad por segundo, incluido el deterioro corporal.
	No recibe la recompensa oculta del objeto. Puede aprender efectos negativos y cambiar de opinión.
	Los efectos saturados por llegar a 0/100 también sesgan lo que observa.
	Aún no aprende secuencias, no generaliza entre objetos parecidos y no atribuye bien efectos
	que cambian durante un ensayo. El desplazamiento tiene coste estimado, no aprendido.
	No hay rescate automático al tener hambre ni muerte implementada al llegar a cero.
	
	## Observar sin dirigir
	1. Elegir semilla y parámetros. Pulsar F5 y R para empezar sin memoria experimental.
	2. Usar 1/2/3 para x1/x4/x10. No dejar pescado con clic si queremos observar sin ayuda.
	3. Anotar cuánto tarda en probar algo, qué repite, qué evita y qué necesidades caen a cero.
	4. Repetir con varias semillas, cambiando UNA variable cada vez y pulsando R en cada ensayo.
	5. No exigir que haga una acción particular: comparar diversidad, aprendizaje, mínimos y adaptación.
	
	La semilla controla solo el selector: el mundo conserva otras fuentes de azar y el paso de tiempo
	varía entre ejecuciones. No es todavía una simulación totalmente reproducible.
	
	## Registro local y memoria
	`user://gatito_free_brain_v1.json`, independiente de `gatito_brain.json` clásico.
	Guarda parámetros de la sesión, semilla, memoria acumulada, mínimos de la sesión y hasta
	200 ensayos recientes con cambios por segundo y necesidades finales. Se guarda cada 20 s
	de juego y al salir. No envía datos a ningún servidor.
	El HUD muestra ensayos y recuerdos. R reinicia exclusivamente la memoria experimental.
	Para comparar sesiones, copiar el JSON antes de reiniciar; no hay archivado automático.
	Cambiar parámetros no borra el aprendizaje: usar R para una comparación desde cero.
	
	## Validación inicial
	- 3 contratos automáticos del cerebro libre y 7 regresiones del clásico aprobados.
	- Una ejecución real de 14 s con aceleración x10 mostró 17 ensayos y 16 recuerdos distintos,
		sin errores de ejecución. La saciedad llegó a cero: NO demostró aprender a alimentarse a tiempo.
	- Falta estudio prolongado de varias semillas y adaptación al cambiar el mundo.
	