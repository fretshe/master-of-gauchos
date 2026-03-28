# Summoners of the Andes - Documentacion del Proyecto

## Vision general
- Juego de estrategia tactica por turnos sobre grilla hexagonal.
- Presentacion 3D con unidades 2D tipo billboard.
- Inspiracion: wargames tacticos ligeros con progresion meta estilo roguelike.
- Loop principal: menu principal -> configuracion de partida -> combate -> game over -> progreso/desbloqueos -> nueva partida.

## Stack tecnico
- Engine: Godot 4.x
- Lenguaje: GDScript
- Resolucion base: 1280x720
- UI: construida mayormente por codigo
- Plataforma objetivo actual: Windows Desktop

## Escenas principales
- `TitleScreen.tscn`: menu principal, continuar, desbloqueos
- `NewGameSetup.tscn`: configuracion de facciones, mapa y jugadores
- `Main3D.tscn`: partida principal
- `GameOver.tscn`: resumen de partida y desbloqueos nuevos

## Autoloads principales
- `GameData.gd`: estado global de partida, progreso meta, guardado/carga
- `FactionData.gd`: facciones, colores, nombres y rutas de sprites
- `AudioManager.gd`: SFX
- `MusicManager.gd`: musica de menu y batalla
- `VFXManager.gd`: textos y efectos visuales 2D
- `CardManager.gd`: mazo, manos, cartas equipadas y cartas jugadas

## Sistemas principales

### Combate
- Turnos alternados por jugador con `TurnManager.gd`
- Movimiento y combate gestionados desde `HexGrid3D.gd`
- Resolucion de dano y dados en `CombatManager.gd`
- Victoria por eliminacion del Maestro rival o dominacion total de torres

### Recursos y control del mapa
- La Esencia es el recurso principal
- Las torres generan ingreso por turno
- Capturar torres altera economia y condicion de victoria

### Invocacion
- Se invoca desde el HUD y `SummonMenu.gd`
- Las unidades se colocan junto al Maestro
- El costo depende del tipo de unidad

### Cartas
- Cada jugador roba cartas durante la partida
- Las cartas pueden dar esencia, curar, dar experiencia o causar dano
- Hay soporte para cartas especiales provenientes de desbloqueos meta

### HUD y presentacion
- HUD dinamico con recursos, turno, minimapa, ventaja de partida y panel de unidad
- Menu de pausa con reanudar, guardar, guardar y salir, reiniciar y volver al menu
- Ciclo visual de dia/noche y feedback de combate

## Facciones actuales
- Gauchos
- Militares

Cada faccion tiene sprites propios para:
- Maestro
- Guerrero
- Arquero
- Lancero
- Jinete

## Tipos de unidad
- Warrior
- Archer
- Lancer
- Rider
- Master

## Jugadores
- Soporte para 2 a 4 jugadores
- Cada jugador puede ser humano o IA
- La partida actual usa configuracion flexible desde `NewGameSetup.gd`

## Flujo actual de partida
1. Elegir mapa, facciones y modos de jugador
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

## Progresion meta
- Se registran partidas finalizadas
- El progreso entre partidas vive en `GameData.gd`
- Hay panel de `Desbloqueos` en el menu principal
- Los desbloqueos pueden equiparse y modificar partidas futuras
- Ejemplo implementado:
  - `Alijo Gaucho`
  - Se desbloquea tras jugar 5 partidas con Gauchos como Jugador 1
  - Agrega una carta especial al mazo de Gauchos

## Datos y arquitectura relevante
- `Main3D.gd`: orquestacion de la partida
- `HexGrid3D.gd`: tablero, unidades, torres, seleccion, restauracion de estado
- `HUD.gd`: interfaz principal y pausa
- `SummonMenu.gd`: seleccion de unidades a invocar
- `CardHand.gd`: mano visible y uso de cartas
- `TitleScreen.gd`: menu principal y overlay de desbloqueos
- `GameOver.gd`: resumen de run y recompensas

## Estado actual del proyecto
- Juego principal funcional en 3D
- Menu principal propio con identidad visual
- Setup de nueva partida unificado
- Sistema de cartas activo
- Guardado en partida implementado
- Continuar funcional
- Progresion meta inicial implementada
- Exportacion a Windows funcionando

## Pendientes sugeridos
- Ampliar arbol de desbloqueos por faccion
- Agregar mas recompensas meta aparte de cartas
- Refinar la separacion de mazos por jugador/faccion
- Mejorar IA
- Balancear economia, cartas y unidades
- Reforzar documentacion de estadisticas y valores de combate
