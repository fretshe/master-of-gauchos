# Summoners of the Andes - Gamedesign

## Vision general
- Juego de estrategia tactica por turnos sobre grilla hexagonal.
- Presentacion 3D con unidades 2D tipo billboard.
- Inspiracion: wargames tacticos ligeros, boardfeel visible y tutorial guiado.
- Loop principal: menu principal -> nueva partida o tutorial -> combate tactico -> game over -> progreso meta -> nueva partida.

## Stack tecnico
- Engine: Godot 4.x
- Lenguaje: GDScript
- Resolucion base: 1280x720
- UI: construida mayormente por codigo
- Plataforma objetivo actual: Windows Desktop
- Build actual: `Beta 0.1.4`

## Escenas principales
- `TitleScreen.tscn`: menu principal, opciones, tutorial y desbloqueos
- `NewGameSetup.tscn`: configuracion de facciones, mapa y jugadores
- `TutorialMenu.tscn`: selector de capitulos del tutorial
- `Main3D.tscn`: partida principal
- `GameOver.tscn`: resumen de partida y desbloqueos nuevos

## Autoloads principales
- `GameData.gd`: estado global, progreso meta, guardado/carga, version y patch notes
- `FactionData.gd`: facciones, colores, nombres y rutas de sprites
- `AudioManager.gd`: SFX
- `MusicManager.gd`: musica de menu, turno y batalla
- `VFXManager.gd`: efectos visuales 2D y feedback de combate
- `CardManager.gd`: mazo, manos, cartas equipadas y cartas jugadas

## Sistemas principales

### Combate
- Turnos alternados por jugador con `TurnManager.gd`
- Movimiento y combate gestionados desde `HexGrid3D.gd`
- Resolucion de dano, criticos y respuesta defensiva en `CombatManager.gd`
- Victoria por eliminacion del Maestro rival o dominacion total del tablero
- Los criticos duplican el dano final del golpe
- El bonus de critico por ciclo dia/noche aplica tanto al atacante como al defensor
- Los criticos normales ahora tienen:
  - `critical_hit`
  - `crowd_crit`
  - leve shake de camara
- Los criticos maximos especiales agregan escalones de intensidad:
  - unidad Oro: `heavy_impact` + `crowd_gold` + shake mayor
  - Maestro: `massive_impact` + `crowd_master` + shake fuerte + burst de particulas + pulso del tablero

### Recursos y control del mapa
- La Esencia es el recurso principal
- Las torres generan ingreso por turno
- Capturar torres altera economia, ritmo de invocacion y presion territorial
- El tutorial explica explicitamente que sin esencia no se pueden invocar refuerzos

### Invocacion
- Se invoca desde el HUD y `SummonMenu.gd`
- Las unidades se colocan junto al Maestro
- El sistema valida invocacion solo en casillas adyacentes validas
- Agua y Cordillera siguen bloqueadas como casillas no transitables / no invocables
- Existe preview fantasma sobre casillas validas al pasar el mouse

### Cartas
- Cada jugador roba cartas durante la partida
- Tipos base actuales:
  - Esencia
  - Curacion
  - Dano
  - Experiencia
  - Refresh
- Las cartas ya usan arte dedicado por archivo y el texto se monta sobre el sprite
- Preview hover enriquecido con color semantico y lectura de objetivo
- La IA ya muestra y resuelve mejor sus cartas, con un tempo mas pausado y VFX visibles
- Las cartas base y desbloqueables pueden equiparse o quitarse del mazo desde la pantalla de Desbloqueos
- El limite de cartas extra equipadas por faccion se sigue respetando desde `GameData.gd`

### HUD y presentacion
- HUD superior reordenada con recursos, turno/ciclo, ventaja, velocidades y menu
- Controles de velocidad `x1`, `x2`, `x3` durante partida
- Boton de mapa tactico desplegable, oculto por defecto
- El panel de contexto de casilla puede activarse o apagarse desde opciones
- HUD de unidad con dos modos:
  - simple
  - detalle
- El HUD simple es compacto y fijo abajo a la izquierda
- El HUD detallado se expande desde ese mismo bloque
- La mano de cartas se distribuye entre `Invocar` y `Fin de turno`, preparada para crecer
- Los textos clave del tutorial usan iconos inline como parte del texto
- La subida de nivel usa una presentacion especial con foco sobre la unidad, opciones laterales y atajos `1` y `2`

## Tutorial

### Enfoque actual
- El onboarding fuerte ya no depende solo de una partida normal
- Existe un menu `Tutorial` en el menu principal
- El progreso de capitulos se guarda y muestra estado completado

### Capitulos disponibles
- Capitulo 1: fundamentos, recursos, informacion de unidad, torres, invocacion, ganar la partida y primer combate
- Capitulo 2: invocacion, counters y bonus de terreno
- Capitulo 3: cartas, lectura tactica y uso intencional de efectos

### Principios pedagogicos implementados
- mapas hechos a mano
- pasos bloqueados hasta ejecutar la accion correcta
- flechas de guia secuenciales
- foco / spotlight sobre la UI y elementos del tablero
- cierre de capitulo con resumen y regreso al menu de tutorial
- Los pasos de invocacion ya distinguen entre flecha a unidad y flecha a casilla objetivo

## Facciones actuales
- Gauchos
- Militares
- Nativos
- Brujos

Cada faccion tiene sprites propios para:
- Maestro
- Guerrero
- Arquero
- Lancero
- Jinete

## Tipos de unidad
- Maestro
- Guerrero
- Arquero
- Lancero
- Jinete

## Reglas de combate relevantes
- Solo `Arquero` y `Maestro` tienen verdadero ataque a distancia
- Montana y bosque aumentan la cantidad de golpes, no el alcance
- El agua debilita el ataque
- `Arquero` y `Maestro` pueden responder a ataques a distancia si estan en rango
- No existe aun una estadistica explicita de bloqueo, armadura o reduccion de dano

## Jugadores
- Soporte para 2 a 4 jugadores
- Cada jugador puede ser humano o IA
- La partida actual usa configuracion flexible desde `NewGameSetup.gd`
- Existe soporte para prueba pasiva entre IAs
- El setup permite presets rapidos (`Duelo`, `3 jugadores`, `Caos`, `Mezclar`)
- El setup permite faccion `Aleatorio`
- El color de jugador ahora se define con desplegable en lugar de botones circulares

## Flujo actual de partida
1. Elegir mapa, facciones y modos de jugador
   - se pueden usar presets, semilla manual o aleatoria y facciones aleatorias
2. Entrar a `Main3D`
3. Jugar combate tactico por turnos
4. Guardar durante la partida o usar guardar y salir
5. Finalizar en `GameOver`
6. Registrar progreso meta y desbloqueos

## Guardado y continuidad
- Existe guardado de partida en progreso
- El menu principal habilita `Continuar` solo si hay una partida valida guardada
- El guardado conserva:
  - turno actual
  - esencia
  - mazo y manos
  - unidades y torres
  - progreso estadistico de la partida
  - estado del tutorial / modo de capitulo cuando corresponde

## Progresion meta
- Se registran partidas finalizadas
- El progreso entre partidas vive en `GameData.gd`
- Hay panel de `Desbloqueos` en el menu principal
- Los desbloqueos pueden equiparse y modificar partidas futuras
- La logica de mazo ya contempla equipar o desequipar tambien las cartas base
- Ejemplo implementado:
  - `Fogon Gaucho`
  - cartas de faccion propias de Gauchos

## Cartas y contenido actual

### Cartas base
- Esencia: `+2`, `+3`, `+4`, `+5`
- Curacion: `+2`, `+4`, `+6`
- Dano: `2`, `3`, `4`, `5`
- Experiencia: `+1`, `+2`, `+3`

### Cartas de faccion activas
- Gauchos:
  - `essence_6_legendary`
  - `Fogon Gaucho`
- Nativos:
  - cartas propias integradas
  - incluye modificacion especial de torre persistente para ciertos efectos

### Efecto actual de Fogon Gaucho
- Tipo: `refresh`
- Objetivo: unidad aliada agotada
- Efecto: reinicia su estado de accion para que pueda volver a jugar ese turno

## Datos y arquitectura relevante
- `Main3D.gd`: orquestacion de partida, tutorial y uso de cartas
- `HexGrid3D.gd`: tablero, unidades, torres, highlights, restauracion de estado y teatro de combate
- `CombatManager.gd`: resolucion de dano, criticos, respuesta, audio y VFX especiales
- `HUD.gd`: interfaz principal, tutorial, spotlight, preview de combate y HUD de unidad
- `LevelUpMenu.gd`: presentacion de ascenso de nivel y seleccion de mejoras
- `SummonMenu.gd`: seleccion de unidades a invocar
- `CardHand.gd`: mano visible, hover, layout de cartas y uso
- `TitleScreen.gd`: menu principal, opciones y accesos
- `NewGameSetup.gd`: configuracion de partida, presets, facciones aleatorias, preview de mapa y colores de jugador
- `TutorialMenu.gd`: selector de capitulos
- `GameOver.gd`: resumen de run y recompensas

## Estado actual del proyecto
- Juego principal funcional en 3D
- Tutorial de 3 capitulos jugable
- Menu principal con logo y acceso a tutorial
- Setup de nueva partida unificado
- Setup de nueva partida en proceso de refinamiento visual y de UX
- Sistema de cartas activo con artes integrados
- Guardado en partida implementado
- Continuar funcional
- Progresion meta inicial implementada
- Exportacion a Windows funcionando
- Fullscreen y layout principal corregidos en la mayor parte de la UI
- Bosque con variantes visuales propias y decoracion de terreno mas rica

## Pendientes sugeridos
- Cartas de faccion para Militares, Nativos y Brujos
- Balance fino de criticos, economia y respuesta a distancia
- Mas variedad de SFX y lectura sonora por unidad / faccion
- Mejorar IA estrategica en uso de cartas e invocacion
- Revisar masallas de fullscreen y offsets finos en todos los paneles
- Documentar valores finales de dados, ataques por terreno y curvas de exp
