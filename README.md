# AICatIsland 🐱🏝️

Concepto en **Godot 4.7** (2D isométrico): una isla ficticia del Japón antiguo donde un gatito
vive **solo**, guiado por pocas pautas simples, y va descubriendo, aprendiendo y evolucionando.

La isla conserva el arte **principalmente procedural**, inspirado en el grabado *ukiyo-e*, con contornos
de tinta y colores cálidos. El gato naranja atigrado usa sprites generados con IA,
con siete animaciones: caminar, reposar, dormir, comer, jugar, escarbar y acicalarse.
Los dos chōchin de papel también usan sprites basados en referencia. El mar es un shader procedural.

## Qué hay
- Isla procedural con playa, hierba y musgo; mar con olas, espuma, reflejos y destellos
- Árboles japoneses (sakura, momiji, pino niwaki, bambú), santuario con interior, chōchin de vela, torii
- Ciclo de día y noche con atardecer cálido, ambiente lunar frío y velas de encendido gradual
  (el sol y la luna todavía no aparecen como cuerpos visibles)
- **IA del gato sin servicios externos**: necesidades + puntuación de acciones + aprendizaje por experiencia
- **Descubrimiento**: el mundo define qué hace cada cosa (montículos, roca con cangrejo, matatabi,
  guarida…) y el gato lo aprende probando verbos básicos (olfatear, escarbar, zarpazos, morder, tumbarse)
- Personalidad que cambia con el tiempo y memoria persistente entre sesiones (`user://gatito_brain.json`)
- El gato habla según su ánimo, lo que le pasa y lo que recuerda

## Cómo probarlo
Abrir el proyecto en Godot 4.7 y pulsar **F5** (escena `res://scenes/main.tscn`).

| Tecla / ratón | Acción |
|---|---|
| Clic en la orilla | Dejar un pescado |
| Rueda | Zoom |
| Clic derecho + arrastrar | Mover cámara |
| C | Seguir al gato |
| 1 / 2 / 3 | Velocidad x1 / x4 / x10 |
| H | Ocultar paneles |
| F / F11 | Pantalla completa |
| R | Borrar la memoria del gato |

## Estructura
```
scenes/main.tscn          escena principal
scripts/cat/cat.gd        cerebro, voz y animación del gato
assets/cat/              atlas limpios usados en el juego (celdas de 112×112)
assets/generated/        originales y metadatos de generación
scripts/world/            isla, agua, árboles, objetos, descubribles, día/noche
shaders/water.gdshader    mar procedural
scripts/ui/hud.gd         paneles de observación
tests/test_cat_ai.gd      pruebas de la IA (simulan días sin intervención)
Pendientes.md             hoja de ruta
```

Ver **[Pendientes.md](Pendientes.md)** para lo hecho y lo que viene.

## Experimento de autonomía (activo por defecto)
El modo experimental reemplaza el selector clásico, sin borrarlo. No incluye reglas
como hambre→pescado o miedo→farol. Ver [EXPERIMENTO.md](EXPERIMENTO.md) para ajustar
variables, estudiar resultados y entender sus límites.

### Test visual de día/noche
Abrir `res://tests/dev_day_night.tscn` y pulsar **F6**. El botón alterna entre
12:00 y 21:00 en cuatro segundos, pasando por atardecer o amanecer. La hora queda
fija al terminar; no guarda ni carga la memoria del gato ni adelanta el contador de días.
