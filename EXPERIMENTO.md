# Experimento de autonomía — generalización v2

## Qué estamos probando
No ordenar soluciones: ofrecer verbos y aprender qué cambia en el cuerpo después de usarlos.
El modo está activo por defecto en `Cat.experimental_mode`. Desactivarlo devuelve el cerebro clásico.
No se promete supervivencia, conciencia ni inteligencia general.

## Variables libres
Seleccionar `Entities/Cat/FreeBrain` en main.tscn y modificar en el Inspector:
- `awake_island_hours`: horas despierto para gastar 90 puntos de energía base (8); depende de la duración del día. Desde 100, alcanza 10 tras 8 horas de isla sin efectos adicionales.
- `sleep_recovery_per_second`: energía por segundo de juego mientras duerme (4.5).
- `sleep_wake_energy`: energía objetivo para despertar (85).
- `satiety_minutes`: minutos despierto para gastar 100 de saciedad (6); desde 75 inicial, unos 4.5 minutos sin comer, con menor gasto dormido.
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
Conserva además modelos por apariencia + verbo: tras probar un ejemplar puede usar esa experiencia con otros y en otro contexto. No consulta nutrition ni efectos del mundo al elegir.
Las etiquetas de apariencia las suministra el juego; no son visión neuronal aprendida.
Combina evidencia local y general; cuenta familiaridad por apariencia para no volver a tratar cada zona de suelo como totalmente nueva.
No interpreta una barra que permanece saturada en 0/100 como prueba de efecto nulo. Los cambios que alcanzan un límite solo dan una cota del efecto.
Aún no aprende secuencias ni atribuye bien efectos que cambian durante un ensayo. El desplazamiento tiene coste estimado, no aprendido.
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

## Revisión de saciedad y suministro
- Ocho pescados iniciales, máximo doce; reposición cada ocho segundos de juego (más rápida al amanecer).
- Separación mínima 1.3 celdas, costa real y sitio transitable para interactuar. No aparecen dirigidos al gato.
- La forma plateada/alargada no tiene valor alimentario innato. Solo los cambios corporales experimentados crean esa asociación.
- Los modelos generales nacen vacíos y se guardan en el mismo archivo compatible. Los recuerdos antiguos se conservan, sin inventar resultados para rellenar modelos.
- Los ejemplares consumidos dejan de ser destinos activos; el conocimiento compartido permanece. Falta planificar visitas futuras a zonas donde ya encontró comida.
- La saciedad baja más despacio para permitir experimentación; no hay rescate ni regla hambre→pescado.
- El HUD muestra modelos compartidos y pescados consumidos en la sesión.
- Para comparar desde cero: entrar al juego y pulsar R; solo borra memoria experimental, no reinicia necesidades ni el mundo.
- 28 pruebas aprobadas, incluido suministro, transferencia entre ejemplares/contextos y barras saturadas.
- Vista dev ejecutada sin errores con peces distribuidos; todavía no se ha demostrado alimentación autónoma sostenida con varias semillas.

## Sueño y prioridades vitales
- El descanso `lie` mantiene al gato despierto y usa pose sentada; ya no otorga la recuperación corporal del sueño.
- Debajo de 10 de energía entra en sueño donde está, salvo hambre o seguridad por debajo de 10; despierta al recuperar 85 por defecto. Aún no elige un lugar seguro para dormir.
- Hambre o seguridad críticas interrumpen el sueño y bloquean otro hasta recuperar ambas a 20. Este bloqueo puede impedir dormir indefinidamente si no resuelve la necesidad.
- La fatiga base equivale a 90 puntos en ocho horas de isla; otros efectos pueden variar el resultado. El tiempo de isla avanza con la velocidad del juego.
- Al empeorar hambre/seguridad aumenta el peso de efectos ya aprendidos y disminuyen azar y novedad; no se le dice qué objeto es comida. No hay interrupción general de acciones despierto ni planes de varios pasos todavía.
- Se guardan las necesidades y el estado de sueño con la memoria experimental; una partida vieja sin esos campos conserva valores iniciales. R borra aprendizaje, no reinicia necesidades.
- La supervivencia sostenida y los patrones de sueño aún requieren observación en vivo; las pruebas unitarias no la demuestran.
- Plan de expresión propuesto en PLAN_TEXTOS_GATITO.md; todavía no se implementa.

## Mar y peces varados
- Cardúmenes decorativos nadan en el agua; no son recursos ni seleccionables por el cerebro.
- Los recursos Fish se varan sobre tierra transitable: 1 inicial, máximo 5, nuevo intento cada 35 s de juego (más rápido al amanecer). Son configurables en Main.
- Los varados aparecen mediante reposición en la costa; aún no hay animación ni transferencia individual del cardumen hacia la playa.
- Los valores anteriores de 8 iniciales/12 máximo/8 s en la sección histórica ya no son los actuales. Observar si la menor abundancia permite aprender a alimentarse.
