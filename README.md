# AICatIsland 🐱🏝️

Concepto en **Godot 4.7** (2D isométrico): una isla ficticia del Japón antiguo donde un gatito
vive **solo**, guiado por pocas pautas simples, y va descubriendo, aprendiendo y evolucionando.

Todo el arte está **dibujado con código** (sin imágenes): estilo de grabado *ukiyo-e*,
contornos de tinta y colores planos. El mar es un shader procedural.

## Qué hay
- Isla procedural con playa, hierba y musgo; mar con olas, espuma, reflejos y destellos
- Árboles japoneses (sakura, momiji, pino niwaki, bambú), santuario con interior, faroles tōrō, torii
- Ciclo de día y noche con luces
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
scripts/cat/cat.gd        cerebro, voz y dibujo del gato
scripts/world/            isla, agua, árboles, objetos, descubribles, día/noche
shaders/water.gdshader    mar procedural
scripts/ui/hud.gd         paneles de observación
tests/test_cat_ai.gd      pruebas de la IA (simulan días sin intervención)
Pendientes.md             hoja de ruta
```

Ver **[Pendientes.md](Pendientes.md)** para lo hecho y lo que viene.
