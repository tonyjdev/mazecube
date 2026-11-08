# Juego de puzles del cubo — Especificación inicial

> Documento de referencia con las características acordadas hasta el 7 de noviembre de 2026. Nombre del juego pendiente de definir (nombre provisional del proyecto: *Maze Cube*).
>
> Estados usados en este documento:
> - **Confirmada / Decidido:** acordado explícitamente.
> - **Implementada en el prototipo:** comportamiento propuesto durante el desarrollo y presente en el prototipo, pendiente de confirmación definitiva.

## 1. Concepto

Juego de puzles para móviles Android en el que un cubo recorre automáticamente un laberinto formado por casillas. El jugador únicamente puede cambiar su rumbo hacia la izquierda o hacia la derecha para llevarlo desde un punto de inicio (A) hasta una meta (B).

El diseño busca combinar **lógica y planificación** con **controles y reglas fáciles de entender**, dirigido también a jugadores poco familiarizados con los juegos de estrategia.

## 2. Mecánica principal — Confirmada

### 2.1. Movimiento automático

- El cubo avanza de forma automática siguiendo su dirección actual.
- El jugador no necesita mantener pulsado un control para avanzar.
- El recorrido está organizado en casillas de un laberinto.

### 2.2. Rodar sobre las aristas

- Cada avance de una casilla consiste en **volcar el cubo 90° sobre la arista inferior situada en la dirección de desplazamiento**.
- El cubo apoya sucesivamente distintas caras sobre el suelo.
- **No se desliza, no salta y no rota sobre su propio eje vertical para cambiar de rumbo**.
- Durante el vuelco, la arista utilizada como pivote permanece en contacto con el suelo.

### 2.3. Controles: dos acciones

- **Izquierda:** el siguiente movimiento del cubo es un vuelco de 90° hacia la izquierda respecto a su rumbo actual.
- **Derecha:** el siguiente movimiento es un vuelco de 90° hacia la derecha respecto a su rumbo actual.
- Tras el giro, la dirección elegida pasa a ser el nuevo rumbo de avance automático.
- Los controles son **relativos al rumbo del cubo**, no a direcciones absolutas del tablero o de la pantalla.
- **Media vuelta:** pulsar **izquierda y derecha a la vez** (ver apartado 2.12).

**Ejemplo:** si el cubo avanza hacia arriba en el tablero y el jugador pulsa izquierda, vuelca sobre la arista inferior izquierda y continúa avanzando hacia la izquierda. Si después vuelve a pulsar izquierda, su nuevo rumbo será hacia abajo.

### 2.4. Rebote contra paredes — Confirmada

- El cubo está **siempre en movimiento**: nunca se detiene al encontrar un obstáculo.
- Cuando la casilla siguiente en su rumbo es una **pared o el borde del tablero**, el cubo **rebota**: invierte su rumbo y continúa avanzando automáticamente en sentido contrario.
- El rebote es **inmediato**, sin animación de choque ni inclinación hacia la pared: el siguiente movimiento ya es un vuelco normal de 90° en la dirección opuesta.
- El nuevo sentido pasa a ser el rumbo actual, por lo que los giros posteriores a izquierda o derecha son relativos a él.

**Ejemplo:** si el cubo avanza hacia la derecha y la casilla siguiente es una pared, vuelca hacia la izquierda y sigue avanzando hacia la izquierda hasta que el jugador gire o encuentre otro obstáculo.

### 2.5. Giros hacia una pared — Confirmada

- Si el jugador pide un giro y **la casilla en esa dirección está bloqueada** (pared o borde), el giro **no se realiza** y el cubo **continúa moviéndose en su rumbo actual**.
- El giro descartado no se guarda para más adelante: se pierde.
- Si después de descartar el giro la casilla de delante también está bloqueada, se aplica el rebote del apartado 2.4.

**Ejemplo:** si el cubo avanza hacia arriba, a su derecha hay un muro y el jugador pulsa derecha, el cubo sigue avanzando hacia arriba.

### 2.6. Indicador de rumbo — Confirmada

- Sobre el cubo se muestra una **flecha** que indica su rumbo actual.
- Al pulsar un giro, la flecha pasa a señalar la dirección pedida, para confirmar que la pulsación se ha registrado.
- Si el giro no se puede realizar (apartado 2.5), la flecha se muestra **en rojo** señalando la dirección descartada durante un instante y después **vuelve a su color normal** señalando el rumbo real. Además, el móvil **vibra muy levemente** (si la vibración está activada).
- La flecha se puede **ocultar** en Opciones (apartado 7.1).

### 2.7. Momento en que se aplica un giro — Implementada en el prototipo

- La pulsación se detecta en cualquier momento, pero el giro se aplica en el **siguiente límite entre casillas**, cuando el cubo termina el vuelco en curso y antes de empezar el siguiente.
- Para girar en una casilla hay que pulsar mientras el cubo rueda hacia ella o mientras está apoyado en ella.
- Si se pulsa varias veces antes de que se aplique, **solo cuenta la última pulsación** (dos pulsaciones a la izquierda no producen un giro de 180°).
- **No se puede girar en la casilla de salida:** el primer movimiento de cada nivel es siempre en el rumbo inicial, porque no hay tiempo de reacción. Los niveles se diseñan teniendo en cuenta esta regla.

### 2.8. Llaves y puertas — Confirmada

- **Llave:** abre una puerta. El cubo la coge al llegar a su casilla; en ese momento la llave **desaparece del mapa** y pasa a mostrarse **encima del cubo**, por encima de la flecha de rumbo, donde **sigue girando** sobre sí misma.
- Mientras está en el mapa, la llave **gira despacio sobre sí misma**.
- El cubo **solo puede llevar una llave** a la vez. Si ya lleva una y pasa por la casilla de otra, no ocurre nada: la otra llave se queda en el mapa.
- **Puerta:** un bloque más estrecho que el cubo que cierra el pasillo de muro a muro, girado 90° según la dirección de los muros que la rodean.
- Cada llave está asociada a **su propia puerta**, y ambas tienen el **mismo color**. Una llave no abre puertas de otro color. Colores disponibles: **amarillo, naranja, rojo, azul y verde**.
- Una puerta cerrada se comporta como una **pared**: el cubo rebota al chocar con ella (apartado 2.4) y los giros hacia ella se descartan (apartado 2.5), **aunque se lleve su llave**.
- Si el cubo **choca de frente** con una puerta llevando su llave, la **llave desaparece** y la **puerta se hunde en el suelo** (animación de unos 0,6 s); desde que empieza a hundirse, la casilla **ya se puede atravesar**. El cubo **rebota igualmente** en ese movimiento; para pasar por el hueco tiene que volver.
- Como solo se abren de frente, cada puerta debe tener por al menos uno de sus lados un tramo recto por el que el cubo pueda llegar hasta ella.
- Las puertas abiertas y las llaves cogidas se restauran al reiniciar el nivel.

**Ejemplo:** el cubo avanza hacia una puerta amarilla llevando la llave amarilla; al tocarla, la llave desaparece, la puerta se hunde en el suelo y el cubo rebota. En la siguiente pasada atraviesa la casilla donde estaba la puerta.

### 2.9. Muros destructibles — Confirmada

- Muros que se rompen tras **varios golpes**. Se ven como **cubos de piedra con grietas**, más altos que las paredes normales.
- Cada muro tiene un **estado del 5 al 1**, que son los golpes que le quedan: el **5** tiene **pocas grietas** y el **1** **muchas**. Al llegar a **0** el muro se destruye.
- El jugador solo ve el estado por la **cantidad de grietas** (no hay número ni texto); cada golpe muestra al momento las grietas del nuevo estado, y el bloque tiembla: **cuatro empujones rápidos** y cortos en la dirección del golpe.
- Mientras está en pie se comporta como una **pared**: el cubo rebota al chocar con él (apartado 2.4) y los giros hacia él se descartan (apartado 2.5).
- Cada **choque de frente** le quita un golpe y el cubo rebota. El golpe que lo destruye **también rebota**; para pasar hay que volver.
- Al destruirse, el bloque se parte en **pedazos que caen** al suelo y después **desaparecen** (en torno a 1,5 s). Desde el instante de la destrucción la casilla **ya se puede atravesar**, aunque los pedazos sigan cayendo. Al destruirse, el móvil **vibra** (si la vibración está activada); al golpearlo sin romperlo, no.
- Para los power ups cuenta como un rebote contra una **pared** (por ejemplo, se pierde la velocidad).
- Los muros destruidos se restauran al reiniciar el nivel.

### 2.10. Power ups — Confirmada

Objetos que el cubo coge al llegar a su casilla y que modifican su comportamiento durante un tiempo. Al cogerlos desaparecen del mapa (vuelven a su sitio al reiniciar el nivel). Cada tipo de power up tiene **sus propias reglas**, que pueden combinar:

- **Duración:** limitada (segundos) o ilimitada hasta que otra regla termine el efecto.
- **Acumulación:** si coger otro igual mientras está activo suma su efecto (con un máximo) o solo lo renueva.
- **Fin al rebotar:** si el efecto termina al rebotar contra una pared o el borde del tablero, contra una puerta, o en ningún caso.

Los power ups no cambian qué decisiones hay que tomar para resolver un nivel (el número mínimo de giros es el mismo), pero sí el ritmo al que hay que tomarlas.

#### Velocidad

- **Efecto:** aumenta la velocidad del cubo un **25%**.
- **Acumulable sumando:** cada uno suma un 25% sobre la velocidad base (×1,25 → ×1,50 → ×1,75 → ×2,00), con un **máximo de ×2** (4 acumulaciones); a partir de ahí coger más no acelera.
- **Duración ilimitada:** el efecto **se pierde al rebotar contra una pared o el borde del tablero**. Rebotar contra una puerta (cerrada, o al abrirla con su llave) **no** lo quita.
- **Aspecto en el mapa:** un cubo pequeño semitransparente (≈30% de transparencia) que gira rápido sobre sí mismo.
- **Efecto visual:** mientras está activo, el cubo deja tras de sí un rastro de polvo que se desvanece en unos 2,5 segundos; con más acumulaciones el rastro es más opaco.
- **Cámara:** al ir más rápido, la cámara se aleja un poco (ver apartado 5).

### 2.11. Botones y barrotes — Implementada en el prototipo

- **Barrotes:** cierran un pasillo de muro a muro, como una puerta. Son **cinco lanzas horizontales** de metal gris, apiladas en altura, con la **punta en sentido alterno** (la primera hacia un lado, la segunda hacia el otro, y así sucesivamente).
- Al **abrirse**, cada lanza se desliza hacia el **lado contrario a su punta** y queda escondida dentro del muro de ese lado; al **cerrarse** vuelve a salir. La animación dura unos 0,3 s y las lanzas se mueven ligeramente escalonadas.
- Cada juego de barrotes tiene un **estado inicial** propio: **abierto o cerrado**.
- Unos barrotes **cerrados** se comportan como una **pared**: el cubo rebota al chocar con ellos y los giros hacia ellos se descartan. Abiertos, la casilla se atraviesa con normalidad. El cambio de estado es **instantáneo** para la lógica, aunque la animación siga.
- Para los power ups, rebotar contra unos barrotes cerrados cuenta como rebotar contra una **puerta** (no se pierde la velocidad).
- **Botones:** están **pegados a la cara de un muro**: una placa metálica con un pulsador rojo. Solo se accionan cuando el cubo **choca de frente** con ellos; el cubo rebota y el pulsador se hunde y vuelve a salir. Al pulsarlo, el móvil vibra suavemente (si la vibración está activada).
- Para los power ups, el botón cuenta como una **pared**.
- Cada botón tiene asignados **uno o más juegos de barrotes**. Al pulsarlo, **todos** cambian de estado: los abiertos se cierran y los cerrados se abren. Un mismo juego de barrotes puede estar asignado a varios botones. Se puede pulsar tantas veces como se quiera.
- Como solo se accionan de frente, la casilla libre delante del botón debe permitir que el cubo llegue hasta él en esa dirección. En esa casilla no puede haber barrotes (se cerrarían encima del cubo).
- Los barrotes y botones se restauran a su estado inicial al reiniciar el nivel.

**Ejemplo:** un botón tiene asignados dos juegos de barrotes, uno abierto y otro cerrado. Al pulsarlo, el abierto se cierra y el cerrado se abre; al pulsarlo otra vez, vuelven a como estaban.

### 2.12. Media vuelta — Implementada en el prototipo

- Al pulsar **izquierda y derecha a la vez**, el cubo cambia al **sentido contrario** al que lleva, igual que si chocara contra una pared. Si va hacia arriba, pasa a ir hacia abajo.
- Cuentan como «a la vez» si al pulsar un lado el otro **sigue pulsado** o se pulsó hace **menos de 0,15 s**. La primera pulsación pide un giro, pero la media vuelta lo sustituye.
- Se aplica en el **siguiente límite entre casillas**, como los giros (apartado 2.7): el cubo termina el vuelco en curso y da la media vuelta al llegar a la casilla.
- Es un movimiento **grande y costoso**: el cubo se queda **parado unos 200 ms**; por sus **cuatro lados sale humo gris** que se expande y se desvanece (≈0,8 s); la **cámara tiembla** levemente (≈0,25 s) y el móvil **vibra** (si la vibración está activada). En el futuro podría penalizar puntos.
- Mientras está pendiente, la flecha de rumbo señala el sentido contrario.
- Para los power ups cuenta como un rebote contra una **pared** (se pierde la velocidad).
- El resolvedor de niveles **no la usa**: los niveles se diseñan y miden sin media vuelta, que queda como ayuda extra para el jugador.

### 2.13. Enemigos — Implementada en el prototipo

Hay tres tipos de enemigos. Se mueven de casilla en casilla deslizándose (no vuelcan) y en tiempo real, independientemente del ritmo del cubo.

- Todos se mueven solo por casillas libres: las **puertas cerradas, los barrotes cerrados y los muros destructibles** también los detienen. **Nunca entran en la casilla de salida ni en la meta.**
- **Muerte del cubo:** si un **perseguidor** o un **patrullero** toca al cubo, el cubo **explota**: se hincha un instante y revienta en 27 pedazos que conservan los colores de sus caras, saltan, rebotan en el suelo girando y se encogen hasta desaparecer (≈1,6 s en total, con una nube de polvo, temblor de cámara y vibración). **Cuando termina la explosión**, el cubo **vuelve a su casilla de salida** con el rumbo inicial. **Conserva la llave** que llevaba, **pierde los power ups**, y el tablero (puertas abiertas, muros rotos, barrotes) y los enemigos se quedan como estaban. Al reaparecer **parpadea** y es **invulnerable** durante 1,5 s.

#### Perseguidor (esfera)

- Esfera roja con ojos, parecida a los fantasmas de un comecocos.
- **No sabe dónde está el cubo**: mientras no lo detecta, **deambula** al azar por los pasillos (sin dar media vuelta salvo en un callejón sin salida), algo más despacio que el cubo (0,6 s por casilla).
- Cuando el cubo entra en su **radio de acción** (4 casillas de **recorrido**, no en línea recta: las paredes tapan), **lo persigue** por el camino más corto, se enciende de un rojo más intenso, mira fijamente al cubo y acelera (0,46 s por casilla, algo más lento que el cubo, que tarda 0,4 s).
- Si el cubo se aleja más de 8 casillas de recorrido, le **pierde la pista** y vuelve a deambular.
- Al matar al cubo le pierde la pista y **no vuelve a buscarlo durante 3 s**, para que no se quede esperando junto a la salida.
- Los perseguidores y los patrulleros pueden cruzarse entre sí.

#### Patrullero (octaedro flotante)

- Octaedro morado que flota y gira sobre sí mismo. Recorre siempre **la misma ruta** y **nunca se sale de ella** (0,55 s por casilla).
- La ruta se define con tramos rectos desde su casilla: dirección (`R` derecha, `L` izquierda, `U` arriba, `D` abajo) y número de casillas, por ejemplo `"R3 D2 L3 U2"`.
  - **Línea recta:** un solo tramo (`"R4"`), de ida y vuelta.
  - **Ida y vuelta:** varios tramos que no vuelven al principio (`"R3 D2"`); al llegar al final, la recorre al revés.
  - **Circular:** los tramos acaban en la casilla de partida (`"R3 D2 L3 U2"`); la repite siempre en el mismo sentido.
- Si la siguiente casilla de su ruta está cortada (puerta, barrotes cerrados, muro destructible u obstáculo), **espera** a que se libere.
- **Regla de las tres salidas:** la ruta de un patrullero debe tener siempre **al menos tres salidas** (casillas libres junto a la ruta que no forman parte de ella) y **al menos una lateral**, es decir, que salga de una casilla intermedia de la ruta y no de uno de sus extremos (en una ruta circular todas las casillas son intermedias). Así el cubo siempre tiene una vía de escape: nunca hay un pasillo cuya entrada y salida coincidan con los extremos de la ruta, que sería imposible de atravesar porque el patrullero, al dar la vuelta, siempre acaba de frente al cubo.

#### Obstáculo (dodecaedro)

- Dodecaedro verde azulado. **No mata**: es **sólido como un muro**. El cubo rebota al chocar con él y los giros hacia él se descartan; los demás enemigos tampoco pueden atravesarlo. Nunca entra en la casilla del cubo (ni en la que está ni en la que va a entrar).
- **Se anticipa al jugador:** calcula el camino más corto del cubo hasta la meta (como si las puertas y los muros destructibles estuvieran abiertos, pero respetando los barrotes cerrados) y va a la casilla de ese camino a la que puede **llegar antes que el cubo**, la más cercana a él. Si no puede ganar la carrera a ninguna, va a la que menos ventaja le saque el cubo.
- Si ya está sobre ese camino, **se queda quieto bloqueándolo** (se oscurece). Cuando el cubo cambia de zona y su camino deja de pasar por él, **vuelve a moverse** para cortarle el paso en el nuevo camino.
- **No vigila siempre:** tiene una paciencia al azar de **3 a 8 s**. Cuando lleva ese tiempo quieto en la misma casilla, se aburre y se va a dar una vuelta por casillas al azar cercanas (mejor si están fuera del camino del cubo) durante 2,5-5 s, sin hacer caso al cubo; después vuelve a vigilar. Así **nunca bloquea una misma casilla más de 8 s seguidos** y el jugador siempre tiene ocasión de pasar.
- Repiensa su objetivo cada 0,35 s (su tiempo de reacción) y es más lento que el cubo (0,55 s por casilla), así que se le puede ganar una carrera.
- **Mecanismos para evitarlo:** los **barrotes** lo detienen igual que al cubo; pulsando un botón en el momento justo se le puede **encerrar** o dejar fuera.
- Si el cubo queda encajonado entre el obstáculo y un muro (bloqueado delante y detrás), rebota en su casilla a ritmo de vuelco hasta que se libere el paso.

### 2.14. Caída al vacío — Implementada en el prototipo

- Hay zonas del mapa **sin paredes y sin suelo**: el **vacío**. Fuera de los límites del mapa también es vacío. Los niveles con vacío son **islas** (salas con paredes y **mesetas** abiertas sin paredes) unidas por **puentes** de una casilla sobre el abismo; bajo el suelo y las paredes se ve un bloque de roca, algo más claro en las casillas del borde, para que el tablero parezca flotar.
- El vacío **no es un obstáculo**: el cubo **no rebota** en él y los **giros hacia el vacío se aplican** (no se descartan). En un puente, cualquier giro tira al cubo; al final de un puente o en el borde de una meseta hay que girar a tiempo.
- Si el cubo entra en el vacío, **vuelca por el borde**, **cae girando** (≈0,6 s, con un silbido que baja de tono) y **explota en el aire**: los pedazos siguen cayendo sin rebotar. Cuando termina la explosión vuelve a la salida igual que al morir por un enemigo (apartado 2.13). Se cae aunque esté en su tiempo de invulnerabilidad.
- Los enemigos nunca entran en el vacío.

### 2.15. Puentes colgantes — Implementada en el prototipo

- Un **puente colgante** es una fila recta de casillas de tablones sobre el vacío, con cuerdas a los lados y postes en los extremos. Une dos zonas con suelo y **no tiene muros a los lados** (a ambos lados hay vacío). Como en cualquier puente, girar sobre él tira al cubo al vacío.
- Es **inestable**: cada casilla tiene su propia **estabilidad**, que empieza siempre en el **100 %** y baja un **25 %** cada vez que el cubo **sale** de ella, vaya en la dirección que vaya (también al volver sobre sus pasos o dar media vuelta encima). Al perder estabilidad la casilla cruje y suelta un poco de polvo.
- El jugador ve el estado de cada casilla por el **polvo** que suelta y cae al vacío:
  - **100 %:** no suelta polvo.
  - **75 %:** cada 8-10 s cae alguna partícula (1-2).
  - **50 %:** cada 4-7 s caen algunas partículas (2-4).
  - **25 %:** cada 1-2 s caen partículas (4-7). Además, cada 3-5 s la casilla **se balancea** despacio durante ≈1,8 s: se ladea hasta unos 6° hacia un lado y otro, gira un poco sobre sí misma y cabecea (unos 3°), y se hunde y se desplaza de lado unos centímetros. Cada vaivén empieza hacia un lado al azar. Es solo visual: no afecta al cubo.
  - **0 %:** el puente se cae.
- En cuanto **una casilla llega al 0 %**, se cae **el puente entero**: las casillas se desprenden **una tras otra** empezando por la que se ha roto, caen girando con una nube de polvo y desaparecen en el abismo. Esas casillas pasan a ser vacío. Si el cubo sigue sobre el puente, **cae con él** (y vuelve a la salida como en una caída normal).
- Como el cubo sale de la primera casilla mientras aún está sobre la segunda, un puente de dos casillas o más se puede **cruzar 3 veces sin peligro**: en la 4.ª travesía se cae con el cubo encima. Uno de una sola casilla aguanta 4 travesías.
- El estado de los puentes **se mantiene** al morir el cubo, como el resto del tablero. Si se cae un puente imprescindible, hay que **reiniciar** el nivel desde el menú de pausa.
- Los enemigos no pisan los puentes colgantes (los patrulleros no pueden tener rutas que pasen por ellos), así que un puente también sirve para escapar de un perseguidor.

## 3. Escenario y objetivo — Confirmados

- El escenario es un **laberinto**.
- El cubo debe llegar desde una **casilla inicial A** hasta una **casilla de destino B**.
- Las decisiones del jugador consisten en elegir los momentos apropiados para girar a izquierda o derecha.
- El juego está orientado a resolver recorridos mediante lógica y anticipación, sin controles complejos.

## 4. Experiencia buscada

- Mecánica comprensible en poco tiempo.
- Profundidad lógica basada en las consecuencias de decisiones sencillas.
- Puzles accesibles a personas sin experiencia previa con juegos de estrategia.
- Prioridad a la planificación del recorrido frente a controles complicados.

> **Por decidir:** velocidad de avance, duración de cada nivel, comportamiento ante caídas, condiciones de derrota, puntuaciones y ayudas. Se ha comentado como posibilidad un enfoque sin presión de tiempo, pero todavía no se ha fijado como regla definitiva. El comportamiento ante paredes está definido en los apartados 2.4 y 2.5, y la dificultad y el reinicio en el apartado 6.

## 5. Presentación visual

- **Efectos de sonido:** vuelco del cubo (golpe sordo, con el tono un poco al azar), rebote, giro descartado, llave cogida (campanitas), puerta abierta, golpe y derrumbe de muros destructibles, botón y barrotes, power up, media vuelta (soplido), explosión del cubo, caída al vacío (silbido), crujido de un puente colgante al gastarse y su derrumbe, meta (fanfarria), alarma cuando un perseguidor ve al cubo y clic en los botones de la interfaz. Son sonidos sintetizados (no hay grabaciones externas) con `tools/make_sfx.py` y suenan por el canal «SFX».

- **Icono de la aplicación:** un cubo isométrico con los colores de las caras del cubo del juego (amarillo, azul y rojo) y la flecha de rumbo, sobre el fondo marrón del menú con trozos de muro de laberinto. En Android se usa también como icono adaptativo (primer plano, fondo y versión monocromática). Se genera con `tools/make_icon.py`.
- Juego en **3D**, con cubo y laberinto visibles desde arriba.
- **Cámara — Decidido:** vista **cenital ligeramente inclinada**, en perspectiva (unos 65° sobre el tablero). Se descartó la isométrica, que en vertical mostraba el tablero bastante más pequeño. La cámara es fija: no hay opción para cambiarla.
- La animación del cubo debe mostrar claramente el vuelco entre casillas; no basta con trasladar el modelo o simular un deslizamiento.
- **Orientación de pantalla — Confirmada:** el juego se muestra en **horizontal** (apaisado) en el móvil, porque así se maneja mejor con las dos manos. (Antes se jugaba en vertical; se cambió el 7 de noviembre de 2026.)
- **Interfaz de juego — Confirmada:** solo el **número de nivel** arriba a la izquierda, el botón de **pausa** arriba a la derecha y las indicaciones «← Izquierda» y «Derecha →» en las esquinas inferiores. El tablero ocupa el resto de la pantalla. Los menús se describen en el apartado 7.
- **Distancia de la cámara — Confirmada:** la cámara no se aleja más de una **distancia máxima**, la que hace falta para ver entero un tablero de 7×9 casillas (el antiguo nivel 4) en el espacio libre de la pantalla. Así el tablero no se ve diminuto aunque el mapa sea grande.
  - Si el tablero entero cabe a esa distancia, la cámara se acerca hasta encuadrarlo justo en el espacio libre entre los elementos de la interfaz y se queda quieta.
  - Si **no cabe**, la cámara **sigue al cubo** con un **pequeño retraso** y un movimiento **suave**: acelera y frena poco a poco, no se para en seco y no rebota cuando el cubo rebota. Al acercarse al borde del tablero deja de avanzar, de modo que no se ve vacío más allá del muro exterior. En la dirección en la que el tablero sí cabe, se queda centrada.
  - Cada nivel puede fijar su propia **distancia de cámara** (campo `camera_distance`), siempre limitada al máximo. Más adelante se podrá acercar o alejar la cámara durante la partida según la situación del juego; los cambios de distancia también serán suaves.
- **Alejamiento por velocidad — Confirmada:** cuando el cubo va más rápido de lo normal (por un power up o por cualquier otra causa), la cámara se **aleja un poco** para que se vea más mapa: un 30% más de distancia por cada ×1 de velocidad extra (con ×1,25, un 7,5%; con ×2, un 30%). Este alejamiento puede superar la distancia máxima. Al recuperar la velocidad normal, la cámara **vuelve a su distancia**. Ambas transiciones son suaves. Si el tablero entero ya cabe en pantalla, no se aleja.
- **Encuadre de botones — Confirmada:** cuando el cubo se acerca a un botón (a 4 casillas de recorrido o menos de la casilla de delante del botón) y alguno de los barrotes que acciona queda **fuera de pantalla**, la cámara se **aleja y se centra** para que se vean a la vez el cubo, el botón y todos sus barrotes (como mucho, hasta ver el tablero entero). Cuando el cubo se aleja del botón, la cámara **vuelve** a su comportamiento normal; tras pulsarlo, espera **0,8 s** antes de volver para que se vea cómo cambian los barrotes. Si al acercarse ya se ven todos los barrotes, la cámara no cambia. Las transiciones son suaves.

## 6. Niveles — Implementada en el prototipo

### 6.1. Progresión

- El juego tiene **35 niveles** de **dificultad creciente**.
- Los niveles se eligen en el **selector de niveles** (apartado 7.2). Solo se puede entrar en los **completados** y en los **desbloqueados**: el nivel 1 está siempre desbloqueado y completar un nivel desbloquea el siguiente.
- Al llegar a la meta, el nivel queda **completado** y se muestra «¡Nivel completado!» con **Siguiente nivel**, **Repetir** y **Niveles** (vuelve al selector). Tras el último nivel se indica que se han completado todos.
- El jugador puede **reiniciar** el nivel en cualquier momento desde el menú de pausa.
- Los **niveles completados se guardan** en el dispositivo.

### 6.2. Formato de los niveles

- Cada nivel se define como un **mapa de texto**: `#` pared, `.` casilla libre, `A` inicio y `B` meta, junto con el **rumbo inicial** del cubo.
- Llaves y puertas: letra minúscula para la llave y la misma en mayúscula para su puerta — `y/Y` amarillo, `o/O` naranja, `r/R` rojo, `u/U` azul, `g/G` verde.
- Power ups: `s` velocidad.
- Muros destructibles: un dígito del `1` al `5` con los golpes que aguantan (`5` pocas grietas, `1` muchas).
- Barrotes: `c`, `d`, `e`, `f`, `h`, cada letra es un **grupo** (todas las casillas con la misma letra cambian juntas); en **minúscula empiezan abiertos** y en **mayúscula cerrados**. Un mismo grupo puede tener casillas abiertas y cerradas. Debe haber muro justo a ambos lados del pasillo.
- Botones: `p`, `q`, `t`, `v`, `w` en lugar de un muro; el botón se coloca en la cara que da a su **única casilla libre** contigua. El campo `buttons` indica qué grupos de barrotes cambia cada botón, por ejemplo `"buttons": {"p": "cd", "q": "d"}`.
- Enemigos (sobre una casilla libre): `x` perseguidor, `z` obstáculo, y `i`, `j`, `k`, `m`, `n` patrulleros. El campo `patrols` da la ruta de cada patrullero (apartado 2.13), por ejemplo `"patrols": {"i": "D6", "j": "R4 D2 L4 U2"}`.
- Vacío: `~` (ni suelo ni pared; apartado 2.14).
- Puente colgante: `=` (apartado 2.15). Las casillas `=` seguidas forman un puente recto; debe tener vacío a ambos lados y suelo en los dos extremos.
- Opcional: `camera_distance`, la distancia de la cámara para ese nivel (por defecto, la máxima; ver apartado 5).
- Los mapas pueden ser más grandes que la pantalla, apaisados o verticales: la cámara sigue al cubo (apartado 5).

### 6.3. Medida de la dificultad

- La dificultad de un nivel se mide como el **mínimo número de giros** necesario para resolverlo con las reglas del apartado 2 (incluido el rebote, el descarte de giros bloqueados, la ausencia de giro en la casilla de salida, las llaves y puertas y los muros destructibles).
- Los **enemigos** se mueven en tiempo real y el resolvedor no los simula: los perseguidores y patrulleros no cuentan y el obstáculo cuenta como un **muro fijo** en su casilla de partida. El resolvedor sí comprueba que las rutas de los patrulleros solo pasan por casillas libres y no tocan la salida ni la meta y que cumplen la regla de las tres salidas (apartado 2.13).
- Caer al vacío devuelve el cubo a la salida; el resolvedor descarta esos movimientos (nunca usa una caída como atajo).
- El resolvedor sí simula el **desgaste de los puentes colgantes** (las salidas que le quedan a cada casilla forman parte del estado): nunca usa un puente más veces de las que aguanta. También comprueba su forma (recta, con vacío a los lados y suelo en los extremos).
- Ese mínimo se calcula con un **resolvedor automático** que también comprueba que todos los niveles tienen solución.
- **Los niveles actuales son de prueba de mecánicas**; los niveles definitivos los proporcionará el diseñador.
- Los niveles de prueba van de **1 a 27 giros** y crecen de forma progresiva, de **9×5 a 23×17 casillas** (en torno a un 15-20% más de casillas cada uno), alternando mapas apaisados y verticales. Los niveles pequeños caben enteros en pantalla; en los grandes la cámara sigue al cubo.
- Desde el nivel 3 incluyen parejas llave/puerta, y cada puerta es imprescindible (convertida en muro, el nivel no tendría solución). Los niveles 4 y 7 tienen un power up de velocidad y el 9 tres seguidos, para probar la acumulación. Hay muros destructibles en los niveles 2, 5, 7 y 10 (hay que romperlos para pasar) y en el 8 (un atajo: sin romperlo harían falta 26 giros en vez de 14). Los niveles 11 a 13 introducen los botones y barrotes; cada botón es imprescindible (sin él, el nivel no tendría solución). Los niveles 14 a 16 presentan los enemigos, uno por nivel, en laberintos con bucles para poder esquivarlos; por eso sus giros mínimos no siguen la progresión.
- Los niveles **17 a 30** son **mapas grandes** (de 27×19 a 64×34 casillas) que combinan todos los mecanismos y enemigos, con dificultad creciente de **27 a 64 giros**. Se alternan dos tipos de mapa: **salas y pasillos** (salas rectangulares, algunas con pilares, unidas por pasillos de una casilla, rectos o en zigzag) y **laberintos** con pocos bucles. Las puertas, los barrotes cerrados y los muros destructibles están siempre en pasillos de paso obligado (son imprescindibles), cada llave está entre su puerta y la anterior (a ser posible en un rincón apartado) y cada **botón está a 6 casillas o menos de sus barrotes**, para que se vean juntos. Los patrulleros rodean salas o recorren pasillos rectos con salida lateral, lejos de la salida y los perseguidores empiezan a 12 casillas o más de ella.
- Los niveles **31** («Al borde», 33×26, 23 giros) y **32** («El abismo», 39×27, 33 giros) presentan el **vacío**: islas y mesetas unidas por puentes, con puentes sin salida como trampa. El 31 tiene dos parejas llave/puerta y un power up de velocidad en un puente; el 32 añade un patrullero que rodea una meseta, un perseguidor en otra, un botón con barrotes que guardan una llave y un muro destructible, todos imprescindibles.
- Los niveles **33** («El puente colgante», 22×9, 8 giros), **34** («Tablones gastados», 27×9, 13 giros) y **35** («Tres puentes», 31×23, 23 giros) presentan los **puentes colgantes**. En el 33 se cruza el puente dos veces (ida a por la llave y vuelta) y queda al 50 %. En el 34 hay que cruzarlo exactamente las 3 veces que aguanta (queda al 25 %), y si el cubo no gira nada más llegar a la isla de la derecha rebota y gasta una travesía. En el 35 hay tres islas y tres puentes: la ruta corta exigiría cruzar 4 veces el puente principal, así que hay que dar al menos una vez la vuelta por la isla del sur, donde ronda un perseguidor que no puede seguir al cubo a los puentes.
- Los niveles 17 a 30 los crea el **generador de niveles** `tools/build_levels.py` (determinista: con las mismas semillas sale siempre lo mismo), que los valida con el resolvedor y elige, para cada nivel, el candidato cuyo mínimo de giros se acerca más al objetivo.

| Nivel | Nombre | Tamaño | Forma | Parejas llave/puerta | Muros destructibles | Power ups | Botones y barrotes | Giros mínimos |
|---|---|---|---|---|---|---|---|---|
| 1 | Primer giro | 9×5 | apaisado | — | — | — | — | 1 |
| 2 | El muro | 7×9 | vertical | — | 1 (3 golpes) | — | — | 3 |
| 3 | La llave | 11×7 | apaisado | amarilla | — | — | — | 5 |
| 4 | A toda prisa | 7×13 | vertical | naranja | — | 1 velocidad | — | 7 |
| 5 | Escombros | 13×9 | apaisado | roja | 1 (4 golpes) | — | — | 9 |
| 6 | Dos llaves | 9×15 | vertical | amarilla, azul | — | — | — | 10 |
| 7 | Salas | 15×11 | apaisado | verde, naranja | 1 (2 golpes) | 1 velocidad | — | 12 |
| 8 | El atajo | 11×17 | vertical | roja, azul | 1 (3 golpes, atajo) | — | — | 14 |
| 9 | Galerías | 17×13 | apaisado | amarilla, roja, verde | — | 3 velocidad | — | 16 |
| 10 | La gran travesía | 15×17 | casi cuadrado | naranja, azul, verde | 2 (2 y 5 golpes, seguidos) | — | — | 19 |
| 11 | El botón | 19×15 | apaisado | amarilla | — | 1 velocidad | 1 botón, 1 barrote cerrado | 21 |
| 12 | Barrotes | 15×23 | vertical | — | 1 (2 golpes) | — | 2 botones, 4 barrotes (2 cerrados y 2 abiertos); un botón abre unos y cierra otros | 22 |
| 13 | La fortaleza | 23×17 | apaisado | amarilla | 1 (3 golpes) | 1 velocidad | 2 botones, 4 barrotes (3 cerrados y 1 abierto) | 27 |
| 14 | La patrulla | 17×13 | apaisado | — | — | — | — | 12 (3 patrulleros: línea recta, ida y vuelta y circular) |
| 15 | Perseguidos | 15×19 | vertical | — | — | — | — | 14 (2 perseguidores) |
| 16 | El guardián | 15×6 | apaisado | — | — | — | 1 botón, 2 barrotes abiertos para encerrar al obstáculo | 5 (1 obstáculo) |
| 17 | Pasillos | 42×16 | salas y pasillos | amarilla | — | — | — | 27 (1 patrullero) |
| 18 | Laberinto de piedra | 27×19 | laberinto | amarilla, naranja | 1 (3 golpes) | — | — | 30 (1 patrullero) |
| 19 | La celda | 31×28 | salas y pasillos | amarilla | — | — | 1 botón, 1 barrote cerrado | 33 (1 perseguidor, 1 patrullero) |
| 20 | Velocidad punta | 29×21 | laberinto | amarilla, naranja | 1 (3 golpes) | 2 velocidad | — | 35 (2 patrulleros) |
| 21 | Los aposentos | 42×25 | salas y pasillos | amarilla, naranja | — | — | 1 botón, 1 barrote cerrado | 38 (1 patrullero, 1 obstáculo) |
| 22 | Rejas | 33×23 | laberinto | amarilla | 1 (4 golpes) | — | 2 botones, 2 barrotes cerrados | 38 (1 perseguidor, 1 patrullero) |
| 23 | La cacería | 42×28 | salas y pasillos | amarilla, naranja | — | 1 velocidad | 1 botón, 1 barrote cerrado | 43 (2 perseguidores, 1 patrullero) |
| 24 | Las catacumbas | 31×23 | laberinto | amarilla, naranja, azul | 1 (2 golpes) | 1 velocidad | — | 45 (2 patrulleros, 1 obstáculo) |
| 25 | El vigilante | 42×34 | salas y pasillos | amarilla, naranja | — | — | 2 botones, 2 barrotes cerrados | 47 (2 patrulleros, 1 obstáculo) |
| 26 | Persecución | 35×25 | laberinto | amarilla, naranja, azul | — | 1 velocidad | 1 botón, 1 barrote cerrado | 50 (2 perseguidores, 1 patrullero) |
| 27 | La ronda | 53×28 | salas y pasillos | amarilla, naranja | 1 (4 golpes) | 1 velocidad | 1 botón, 1 barrote cerrado | 53 (1 perseguidor, 3 patrulleros) |
| 28 | El bastión | 37×27 | laberinto | amarilla, naranja, azul | 1 (2 golpes) | 1 velocidad | 1 botón, 1 barrote cerrado | 59 (1 perseguidor, 2 patrulleros, 1 obstáculo) |
| 29 | El palacio | 53×34 | salas y pasillos | amarilla, naranja, azul | — | 1 velocidad | 2 botones, 2 barrotes cerrados | 59 (1 perseguidor, 3 patrulleros, 1 obstáculo) |
| 30 | El gran laberinto | 64×34 | salas y pasillos | amarilla, naranja, azul | 1 (3 golpes) | 2 velocidad | 2 botones, 2 barrotes cerrados | 64 (2 perseguidores, 3 patrulleros, 1 obstáculo) |
| 31 | Al borde | 33×26 | islas y vacío | amarilla, naranja | — | 1 velocidad | — | 23 |
| 32 | El abismo | 39×27 | islas y vacío | amarilla, azul | 1 (3 golpes) | — | 1 botón, 1 barrote cerrado | 33 (1 perseguidor, 1 patrullero) |
| 33 | El puente colgante | 22×9 | islas y vacío, 1 puente colgante | amarilla | — | — | — | 8 |
| 34 | Tablones gastados | 27×9 | islas y vacío, 1 puente colgante | amarilla, naranja | — | — | — | 13 |
| 35 | Tres puentes | 31×23 | islas y vacío, 3 puentes colgantes | amarilla, naranja, roja | — | — | — | 23 (1 perseguidor) |

## 7. Menús y controles — Confirmada

### 7.1. Menú principal

- **Jugar:** abre el selector de niveles.
- **Opciones:** volumen de **efectos de sonido** y de **música** (0-100%; canales de audio «SFX» y «Music»; todavía no hay música), **antialiasing** (activado/desactivado), **vibración** (activada/desactivada; al activarla vibra brevemente como prueba), **flecha de dirección** sobre el cubo (mostrar/ocultar) e **idioma** (español o inglés). Los cambios se aplican al momento y se guardan en el dispositivo. Por defecto se usa el idioma del sistema si es español o inglés, y si no, inglés.
- **Créditos:** equipo de desarrollo, gráficos, sonido, tipografía, herramientas y licencia del motor, en una lista que se puede desplazar.
- **Salir:** cierra el juego (igual que pulsar Atrás en la pantalla principal).

### 7.2. Selector de niveles

- Es una **imagen ilustrada del mapa** (`ui/level_select/map.png`, vertical) que ocupa todo el ancho de la pantalla y se **desplaza en vertical**. Tiene un camino que sube desde la **casilla de inicio** (un cubo azul sobre un pedestal, abajo, con el texto «INICIO»/«START») y un **círculo por nivel** a lo largo del camino: el primero es el nivel 1. El juego tendrá **100 niveles**; la imagen actual tiene 115 círculos (los que no tienen nivel se ven como bloqueados).
- El mapa se divide en **cinco zonas**, de abajo arriba, con su nombre en un cartel a la izquierda, alineado a la izquierda y precedido de su número romano en la misma línea («II. LAS TIERRAS SALVAJES»; todos los carteles con el mismo tamaño de letra): **I. El mundo de los cubos**, **II. Las tierras salvajes**, **III. El mundo desconocido**, **IV. Los territorios corrompidos** y **V. El núcleo enemigo** (en inglés: The World of Cubes, The Wildlands, The Unknown World, The Corrupted Territories y The Enemy Core).
- En cada círculo se ve el **número del nivel**. Los **completados** se tapan con un círculo **verde** y el **activo** (el siguiente por jugar) con uno **dorado** que late. En los **bloqueados**, y en los círculos de niveles que aún no existen, el número se ve **atenuado** sobre el gris de la imagen, y no se pueden pulsar.
- Se desplaza **arrastrando** con el dedo (con inercia) o con la rueda del ratón. Al entrar, se centra en vertical en el nivel activo (y se vuelve a centrar si cambia el tamaño de la pantalla mientras el jugador no lo haya movido). Tocar un círculo desbloqueado juega ese nivel. Con el teclado, arriba y abajo cambian el nivel elegido (se marca con un anillo blanco) e Intro lo juega.
- La posición de los círculos, su zona, los huecos de los carteles y el del texto «INICIO» están en `ui/level_select/map.json`, que **se genera a partir de la imagen** con `tools/find_level_circles.py` (detecta los círculos grises, los ordena siguiendo el camino, los carteles y el cubo de inicio). Al cambiar la imagen basta con volver a ejecutarlo y revisar la imagen de control que genera con `--check`. Los círculos verde y dorado (`circle_done.png` y `circle_active.png`) los dibuja `tools/make_circle_sprites.py`.
- **Truco para pruebas** (solo en las versiones de depuración): tocar **5 veces seguidas** el título «Elige un nivel» desbloquea todos los niveles (sin marcarlos como completados). Se guarda en el dispositivo.

### 7.3. Pantalla de carga

- Al entrar en un nivel (desde el selector o con «Siguiente nivel») aparece al momento una **pantalla de carga**: fondo **negro**, el **cubo** del juego **volcando** sobre sí mismo en el centro, el número y el nombre del nivel y el texto «Cargando…».
- Debajo se muestra un **consejo** sobre las mecánicas o los movimientos, elegido al azar de una lista (sin repetir el anterior). Los consejos están traducidos a los dos idiomas.
- El nivel se carga sin bloquear la pantalla (el cubo sigue moviéndose) y se prepara detrás, en pausa. Cuando está listo, «Cargando…» se cambia por el botón **Continuar**; al pulsarlo, la pantalla se desvanece y empieza el nivel.
- **Reiniciar** y **Repetir** no pasan por la pantalla de carga.

### 7.4. Pausa

- El botón de **pausa** (arriba a la derecha) detiene el juego y muestra un menú con:
  - **Continuar:** reanuda la partida.
  - **Reiniciar:** vuelve a empezar el nivel.
  - **Salir:** vuelve al selector de niveles.
- En el móvil, el juego también se pausa al salir de la aplicación (por ejemplo, al recibir una llamada).

### 7.5. Controles

- **Tocar la mitad izquierda de la pantalla** gira a la izquierda y **tocar la mitad derecha** gira a la derecha (relativo al rumbo, como en el apartado 2.3).
- Toda la mitad de la pantalla es zona de toque, sin botones pequeños; cada toque cuenta como una pulsación. Tocar el botón de pausa no cuenta como giro.
- **Media vuelta:** tocar las dos mitades a la vez, con un dedo en cada una (en el teclado, las dos flechas a la vez). Se resaltan las dos indicaciones.
- Las indicaciones de las esquinas inferiores («← Izquierda» y «Derecha →») se resaltan al tocar cada lado.
- El botón **Atrás** de Android pausa y reanuda la partida; en los menús vuelve a la pantalla anterior y, desde el menú principal, cierra el juego.
- En PC se mantienen los controles de teclado (←/A, →/D, R reiniciar, Esc pausa/atrás, Intro/N siguiente nivel) y el clic del ratón se trata como un toque.

## 8. Tecnologías — Decididas y propuestas

| Área | Estado | Tecnología / decisión |
|---|---|---|
| Plataforma objetivo | **Decidido** | Android exclusivamente |
| Motor de juego | **Decidido** | Godot 4 |
| Entorno de desarrollo | **Previsto** | Ubuntu Linux |
| Lenguaje | **Propuesto** | GDScript |
| Renderizador | **Propuesto inicialmente** | Compatibility, sujeto a pruebas |
| Control de versiones | **Propuesto** | Git |
| Asistencia de IA | **Pendiente de elegir** | Se ha valorado Codex y una integración MCP con Godot |
| Backend | **No previsto para el prototipo** | Juego inicialmente local |

Aunque existe experiencia previa con Unreal Engine (Blueprints y C++), se ha elegido **Godot para este juego** por su adecuación a un proyecto pequeño orientado a Android. Unreal Engine sigue siendo una opción para otros proyectos futuros.

## 9. Orientación técnica del prototipo — Propuesta

Para representar fielmente el movimiento del cubo:

1. Mantener el estado lógico de **casilla actual**, **rumbo** y **orientación de las caras**.
2. Comprobar la validez del siguiente desplazamiento según el laberinto.
3. Calcular la **arista inferior de pivote** correspondiente al rumbo elegido.
4. Animar el vuelco de 90° alrededor de esa arista hasta la siguiente casilla.
5. Actualizar el estado lógico al completar el movimiento y continuar automáticamente.

Se ha propuesto usar transformaciones y animaciones calculadas (por ejemplo, con `Node3D`, `Tween` y vectores) en lugar de depender de una simulación física de cuerpos rígidos.

### Alcance del primer prototipo

- Un tablero sencillo con algunas casillas y obstáculos.
- Un cubo 3D que rueda automáticamente sobre aristas.
- Entrada izquierda/derecha, inicialmente mediante teclado para probarlo en PC.
- Cambio de dirección correcto y persistente.
- Un inicio y una meta.
- Prueba de las dos perspectivas de cámara sobre el mismo recorrido *(realizada; se eligió la cenital inclinada)*.
- Adaptación posterior a controles táctiles en Android.

## 10. Posibles ampliaciones — No aprobadas todavía

Estas ideas se mencionaron como posibilidades futuras, **no como requisitos del juego**:

- Caras del cubo con colores o símbolos.
- Casillas o puertas que reaccionen a la cara que queda apoyada sobre el suelo.
- Generación automática de laberintos resolubles *(existe una herramienta de desarrollo que la realiza; ver apartado 6.3)*.
- Validación automática de soluciones y dificultad *(cubierta por el resolvedor del apartado 6.3)*.
- ~~Niveles de complejidad creciente.~~ *Incorporado en el apartado 6.*

## 11. Decisiones pendientes

1. ~~Elegir entre vista cenital inclinada e isométrica.~~ **Decidido:** cenital inclinada (apartado 5).
2. Definir velocidad y ritmo de los vuelcos.
3. ~~Establecer cómo se gestionan pulsaciones mientras el cubo está girando.~~ **Implementado en el prototipo:** apartado 2.7, pendiente de confirmación.
4. ~~Definir qué ocurre al encontrar una pared, un obstáculo o el borde del tablero.~~ **Decidido:** el cubo rebota y sigue en sentido contrario (apartado 2.4); los giros hacia una pared se descartan (apartado 2.5).
5. ~~Diseñar los controles táctiles concretos para Android.~~ **Implementado en el prototipo:** apartado 7, pendiente de confirmación.
6. ~~Decidir formato y creación de niveles.~~ **Implementado en el prototipo:** apartado 6, pendiente de confirmación.
7. Seleccionar el asistente de IA y su integración con Godot.
8. Elegir un nombre para el juego.

---

**Estado del proyecto:** mecánica principal definida y prototipo jugable en Android con 10 niveles; quedan por confirmar las decisiones marcadas como «Implementada en el prototipo» y las del apartado 11.
