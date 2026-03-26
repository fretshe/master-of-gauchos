# Master of Monsters - Documentación del Proyecto

## Stack técnico
- Godot 4.x, GDScript, proyecto 3D con sprites 2D billboard
- Resolución: 1280x720

## Arquitectura de scripts (Autoloads)
- GameData.gd: variables globales, seed, mapa, facciones elegidas
- TurnManager.gd: turnos, jugador activo, fin de turno con Enter, cámara se mueve al Maestro del siguiente jugador
- ResourceManager.gd: esencia por jugador, ingresos por torres
- AudioManager.gd: sonidos SFX con archivos MP3 reales
- MusicManager.gd: música por facción y combate
- VFXManager.gd: textos flotantes 2D en CanvasLayer layer=100, sincronizados con sonido de golpe
- CombatManager.gd: sistema de dados, duelo por rondas, experiencia por combate
- SummonManager.gd: invocación con tecla E cerca del Maestro
- AnimationManager.gd: tweens de movimiento y combate
- FactionData.gd: datos de facciones y rutas de sprites

## Flujo de escenas
- TitleScreen.tscn → FactionSelect.tscn → MapSelect.tscn → Main3D.tscn → GameOver.tscn
- Todo el layout de UI construido 100% por código en _ready()

## Jugadores
- Soporta 2, 3 o 4 jugadores
- Cada jugador elige una facción en FactionSelect

## Facciones disponibles
- Gauchos: sprites PNG propios en assets/sprites/factions/gauchos/
- Militares: sprites PNG propios en assets/sprites/factions/militares/
- Sprites: master.png, warrior.png, archer.png, lancer.png, rider.png

## Sistema de unidades
- 4 tipos: Warrior, Archer, Lancer, Rider + Maestro especial
- 3 niveles: Bronze, Silver, Gold (Maestro empieza en Gold, puede llegar a Diamond)
- XP requerida: Bronze=10, Silver=15, Gold/Diamond=20
- Al subir nivel: HP se cura completamente y max_hp aumenta según tabla
- Al llegar a Diamond y llenar XP de nuevo: curación completa sin subir más

## Vida por unidad y nivel
- MASTER:  Gold=30, Diamond=40
- WARRIOR: Bronze=8,  Silver=16, Gold=26
- ARCHER:  Bronze=5,  Silver=12, Gold=20
- LANCER:  Bronze=10, Silver=20, Gold=35
- RIDER:   Bronze=10, Silver=18, Gold=32

## Sistema de experiencia
- Ambas unidades ganan 1 XP de participación al combatir
- Atacante gana 2 XP adicional si su ataque inflige daño
- Atacante gana 5 XP adicional por derrotar una unidad
- El defensor no gana XP extra por golpes del contraataque

## Sistema de dados
- RED:    [0,0,1,1,2,3]
- YELLOW: [0,0,1,2,3,3]
- GREEN:  [0,0,2,3,3,4]
- BLUE:   [1,2,3,4,4,5]

## Dados por unidad y nivel (índice = nivel-1: 0=Bronze, 1=Silver, 2=Gold)
- WARRIOR:  melee=[YELLOW, GREEN, BLUE],   ranged=[null, null, RED]
- ARCHER:   melee=[RED, YELLOW, YELLOW],   ranged=[YELLOW, GREEN, BLUE]
- LANCER:   melee=[RED, YELLOW, BLUE],     ranged=[RED, YELLOW, GREEN]
- RIDER:    melee=[YELLOW, GREEN, BLUE],   ranged=[null, RED, RED]
- MASTER:   Gold=1 dado BLUE, Diamond=2 dados BLUE (melee y ranged)

## Movimiento
- Una sola vez por turno (moved=true después de mover)
- Warrior/Archer/Lancer: 3 baldosas, Rider: 5, Maestro: 2
- Montaña y bosque cuestan 2 puntos de movimiento, agua infranqueable

## Ataque
- Una sola vez por turno (has_attacked=true después de atacar)
- Ataque a distancia: no permite contraataque del defensor
- Ambas flags se resetean al inicio del turno del jugador

## Contrarrestado de tipos
- Warrior > Lancer, Lancer > Rider, Rider > Archer, Archer > Warrior
- Ventaja: x1.75 daño, Desventaja: x0.6 daño

## Torres
- Pequeño 12x8:  14 torres
- Mediano 24x16: 28 torres
- Grande 36x24:  40 torres
- Enorme 48x32:  56 torres
- Distribución: algunas cerca de cada punto de spawn, mayoría en el centro disputado
- Generan 2 de Esencia por turno al capturarlas

## Cámara 3D
- CameraController3D.gd: WASD/flechas mueven, rueda zoom, clic derecho gira
- Zoom: mínimo Y=5, máximo Y=28
- Teclas de juego: E invocar, Q habilidad Maestro, Enter fin turno, Esc cancelar
- Modo combate: cámara se mueve perpendicular al eje atacante-defensor
- Al salir del combate: restaura transform y zoom previos exactos
- Al cambiar turno: tween suave hacia el Maestro del jugador activo

## Indicadores visuales de unidades
- Aro de color en el hexágono de cada unidad: azul J1, rojo J2, verde J3, amarillo J4
- Aro de selección: parpadeo de emisión dorado, visualmente distinto del aro de equipo
- Sprite modulate con color del equipo (tono suave)

## HUD
- Imagen de fondo: assets/sprites/hud_background.png 1280x720
- Panel superior izquierdo: equipo, torres, esencia, unidades
- Panel superior centro: turno actual
- Panel superior centro-derecha: último combate colapsable
- Minimapa superior derecha: SubViewport con Camera3D ortogonal
- Panel inferior izquierda: portrait, segmentos HP/XP, dados disponibles
- Dados de ataque dimmed (alpha 0.3) si has_attacked=true
- Botón invocar centro inferior, botón fin de turno inferior derecha

## Efectos visuales
- Ciclo de día y noche
- Cel shader aplicado al mapa
- Textos flotantes 2D sincronizados con sonido de golpe
- Animaciones de combate cinematográficas con lunge, recoil y etiquetas de daño
- Partículas y flash de color al subir de nivel

## Audio
- SFX: sword_hit, arrow_hit, lance_hit, walk_01, walk_02, button, tower_capture, essence_gain, summon
- Música: menu.mp3, team_blue.mp3, team_red.mp3, combat.mp3
- Música cambia según jugador activo y durante combate

## Reglas importantes de código
- Todos los scripts usan tipos explícitos: `var x: Type`
- Layout de UI siempre construido por código en _ready(), nunca por .tscn
- Autoloads registrados en project.godot bajo [autoload]
- Billboard usa BILLBOARD_FIXED_Y
- Textos flotantes en CanvasLayer 2D con layer=100
- Tweens: siempre matar el tween activo antes de crear uno nuevo
- Lambdas en tween_method: declarar var antes del bloque if, asignar al menos 2 propiedades para evitar parse errors de GDScript

## Pendiente
- Efectos de terreno (montaña +defensa, bosque +cobertura)
- IA básica para jugador 2
- Guardar y cargar partida
- Retratos de personajes para el HUD
- Tiles de terreno con arte propio
- Animaciones de sprites de facciones
