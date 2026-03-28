# Redisenio del Tutorial

## Objetivo
- Convertir el onboarding actual en una experiencia que ensenie reglas, intencion tactica y flujo de turno.
- Separar la ensenianza profunda de mecanicas del flujo de una partida normal.
- Reducir interpretaciones libres en combate, economia, invocacion y cartas.

## Problemas Detectados
- El tutorial actual presenta interfaz, pero no termina de explicar el por que de las decisiones.
- El jugador no aprende con claridad como se calcula el dano ni por que una unidad conviene sobre otra.
- Capturar torres se percibe como algo opcional en vez de ser la base de la economia.
- Invocar unidades no comunica bien el proceso completo: elegir unidad, ubicarla y justificar la invocacion.
- Las cartas son legibles solo a nivel muy basico y no ayudan a tomar decisiones.
- Falta un primer combate guiado donde el juego deje claro que el jugador puede iniciar ataques.

## Meta de Disenio
Al terminar el onboarding, el jugador debe entender:
- como mover, atacar y terminar turno
- como se gana esencia y para que sirven las torres
- cuando invocar y donde colocar una unidad
- el triangulo basico de ventaja entre unidades
- como leer y usar cartas
- que atacar primero es una accion propia del jugador, no solo de la IA

## Enfoque General
- Mantener un tutorial breve dentro de la primera partida normal solo para orientacion minima.
- Mover la ensenianza real a un menu de tutorial con capitulos separados.
- Usar mapas hechos a mano, con situaciones controladas y una sola leccion importante por tramo.
- Bloquear progreso hasta que el jugador ejecute la accion correcta en cada paso clave.
- Evitar texto abstracto. Cada explicacion debe estar unida a una accion inmediata.

## Nuevo Menu Principal
- Agregar una opcion `Tutorial`.
- Abrir un submenu con 3 capitulos.
- Cada capitulo muestra:
  - nombre
  - objetivo de aprendizaje
  - una breve descripcion
  - estado: disponible, completado

## Estructura Propuesta

### Capitulo 1: Fundamentos de Batalla
Objetivo:
- enseniar seleccion, movimiento, ataque, dados y fin de turno

Lecciones:
- seleccionar una unidad propia
- mover a una casilla marcada
- atacar a un enemigo marcado
- leer un preview simple de combate
- entender que el dano depende de dados y cantidad de golpes
- terminar el turno

Mapa:
- mapa muy pequeno
- un Maestro aliado, una unidad aliada extra, uno o dos enemigos fijos
- una sola ruta util para evitar distracciones

Mensajes clave:
- "Selecciona tu unidad."
- "Las casillas azules indican movimiento posible."
- "Las casillas rojas indican enemigos a los que puedes atacar."
- "Cada combate tira dados. Mas golpes y mejor ventaja significan mas dano esperado."
- "Atacar es una accion activa tuya."

Condiciones de avance:
- no avanzar hasta seleccionar la unidad correcta
- no avanzar hasta moverla
- no avanzar hasta iniciar un ataque
- no avanzar hasta pulsar fin de turno

### Capitulo 2: Torres, Esencia e Invocacion
Objetivo:
- enseniar economia, captura de torres e invocacion

Lecciones:
- mover hacia una torre neutral
- capturarla
- observar ingreso de esencia al siguiente turno
- abrir menu de invocacion
- elegir una unidad concreta
- colocarla en una casilla valida junto al Maestro
- entender por que invocar en ese momento

Mapa:
- dos torres neutrales cercanas
- poca presion enemiga
- espacio claro junto al Maestro para la primera invocacion

Mensajes clave:
- "Las torres generan esencia al inicio de tu turno."
- "Sin esencia no puedes invocar refuerzos."
- "Invoca nuevas unidades junto a tu Maestro."
- "Primero eliges la unidad. Despues eliges una casilla valida para colocarla."
- "Invocar aumenta tu presencia en el mapa y te ayuda a disputar torres o proteger tu Maestro."

Condiciones de avance:
- capturar al menos una torre
- pasar de turno para cobrar esencia
- abrir menu de invocacion
- elegir una unidad sugerida
- colocarla correctamente

### Capitulo 3: Ventajas, Cartas y Decisiones Tacticas
Objetivo:
- enseniar counters, lectura de amenazas y cartas

Lecciones:
- leer una ventaja de combate simple
- entender un ejemplo directo de counter
- elegir entre dos unidades posibles para responder a una amenaza
- usar una carta en un contexto claro
- decidir entre atacar, reposicionarse o invocar

Mapa:
- escenario controlado con dos frentes cortos
- un enemigo vulnerable a cierto tipo de unidad
- una carta en mano que resuelva una situacion puntual

Mensajes clave:
- "No todas las unidades rinden igual contra todos los rivales."
- "Guerrero vence a Lancero."
- "Lancero vence a Jinete."
- "Arquero presiona a distancia."
- "Las cartas son herramientas tacticas: dano, curacion, esencia o experiencia."
- "Antes de actuar, compara amenaza enemiga, esencia disponible y posicion del Maestro."

Condiciones de avance:
- inspeccionar un enemigo
- elegir la unidad recomendada para responder
- usar una carta en el objetivo correcto
- resolver un combate con ventaja

## Mejoras Inmediatas en Partida Normal

### 1. Combat Preview mas claro
- Mostrar cantidad de golpes del atacante y defensor.
- Mostrar texto corto de ventaja o desventaja.
- Agregar una linea breve:
  - `Golpes: 3`
  - `Ventaja: Guerrero > Lancero`

### 2. Torres mas explicitas
- Reemplazar texto grande de ingreso por feedback compacto.
- Usar icono de esencia y texto corto:
  - `+2`
- Agregar durante tutorial un mensaje explicito:
  - "Esta torre te dara esencia en cada turno."

### 3. Invocacion guiada
- Tras elegir unidad en el menu, mostrar inmediatamente:
  - mensaje corto arriba del tablero
  - casillas validas resaltadas
  - texto del tipo "Ahora coloca esta unidad junto a tu Maestro"

### 4. Cartas mas legibles
- Agregar zoom o carta ampliada al hover.
- Mostrar en la version ampliada:
  - nombre
  - efecto
  - valor
  - objetivo valido
  - texto de uso corto

Ejemplos:
- `Esencia +3. Uso inmediato.`
- `Dano 3. Objetivo: unidad enemiga no Maestro.`
- `Curar 4. Objetivo: unidad aliada herida.`

### 5. Primer ataque forzado
- En onboarding, el juego debe obligar a atacar al menos una vez.
- Resaltar enemigo objetivo con indicacion visual fuerte.
- Mensaje minimo:
  - "Haz clic en el enemigo resaltado para atacar."

### 6. Counter explcito en SummonMenu
- Cada carta de invocacion debe incluir un texto corto de rol:
  - Guerrero: fuerte contra Lancero
  - Lancero: fuerte contra Jinete
  - Arquero: dano a distancia
  - Jinete: alta movilidad

## Rol del Tutorial Actual en Main3D
- Dejarlo como tutorial introductorio corto o convertirlo en `Primeros pasos`.
- Reducirlo a:
  - recursos
  - seleccion
  - mover
  - atacar
  - capturar torre
  - invocar
  - terminar turno
- Sacar de ahi explicaciones profundas y derivarlas al menu de tutorial por capitulos.

## Orden Recomendado de Implementacion
1. Mejorar claridad de UI dentro de la partida normal.
2. Agregar tutorial de ataque guiado al flujo actual.
3. Crear entrada `Tutorial` en el menu principal.
4. Implementar Capitulo 1 con mapa hecho a mano.
5. Implementar Capitulo 2.
6. Implementar Capitulo 3.
7. Ajustar textos, timing y bloqueos en base a nuevas pruebas.

## Primer Backlog Accionable
- Agregar boton `Tutorial` al menu principal.
- Definir una forma de cargar mapas tutoriales hechos a mano.
- Separar estado del tutorial actual del flujo de partida normal.
- Crear sistema de pasos con condiciones de avance por objetivo.
- Mejorar preview de combate para explicar dados y ventaja.
- Agregar hover ampliado para cartas.
- Simplificar feedback visual de ingreso por torres.
- Mejorar texto contextual al entrar en modo de colocacion tras invocar.

## Decision de Producto
- La partida normal no deberia cargar con toda la responsabilidad pedagogica.
- El juego necesita un onboarding en capas:
  - capa 1: claridad basica en UI
  - capa 2: primeros pasos dentro de una partida
  - capa 3: tutoriales dedicados y controlados
