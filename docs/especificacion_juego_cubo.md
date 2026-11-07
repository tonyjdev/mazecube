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
- Si el giro no se puede realizar (apartado 2.5), la flecha se muestra **en rojo** señalando la dirección descartada durante un instante y después **vuelve a su color normal** señalando el rumbo real.

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
- Al destruirse, el bloque se parte en **pedazos que caen** al suelo y después **desaparecen** (en torno a 1,5 s). Desde el instante de la destrucción la casilla **ya se puede atravesar**, aunque los pedazos sigan cayendo.
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

## 6. Niveles — Implementada en el prototipo

### 6.1. Progresión

- El juego tiene **10 niveles** de **dificultad creciente**.
- Los niveles se eligen en el **selector de niveles** (apartado 7.2). Solo se puede entrar en los **completados** y en los **desbloqueados**: el nivel 1 está siempre desbloqueado y completar un nivel desbloquea el siguiente.
- Al llegar a la meta, el nivel queda **completado** y se muestra «¡Nivel completado!» con **Siguiente nivel**, **Repetir** y **Niveles** (vuelve al selector). Tras el último nivel se indica que se han completado todos.
- El jugador puede **reiniciar** el nivel en cualquier momento desde el menú de pausa.
- Los **niveles completados se guardan** en el dispositivo.

### 6.2. Formato de los niveles

- Cada nivel se define como un **mapa de texto**: `#` pared, `.` casilla libre, `A` inicio y `B` meta, junto con el **rumbo inicial** del cubo.
- Llaves y puertas: letra minúscula para la llave y la misma en mayúscula para su puerta — `y/Y` amarillo, `o/O` naranja, `r/R` rojo, `u/U` azul, `g/G` verde.
- Power ups: `s` velocidad.
- Muros destructibles: un dígito del `1` al `5` con los golpes que aguantan (`5` pocas grietas, `1` muchas).
- Opcional: `camera_distance`, la distancia de la cámara para ese nivel (por defecto, la máxima; ver apartado 5).
- Los mapas pueden ser más grandes que la pantalla, apaisados o verticales: la cámara sigue al cubo (apartado 5).

### 6.3. Medida de la dificultad

- La dificultad de un nivel se mide como el **mínimo número de giros** necesario para resolverlo con las reglas del apartado 2 (incluido el rebote, el descarte de giros bloqueados, la ausencia de giro en la casilla de salida, las llaves y puertas y los muros destructibles).
- Ese mínimo se calcula con un **resolvedor automático** que también comprueba que todos los niveles tienen solución.
- **Los niveles actuales son de prueba de mecánicas**; los niveles definitivos los proporcionará el diseñador.
- Los niveles de prueba van de **1 a 19 giros** y crecen de forma progresiva, de **9×5 a 15×17 casillas** (en torno a un 15-20% más de casillas cada uno), alternando mapas apaisados y verticales. Los niveles pequeños caben enteros en pantalla; en los grandes la cámara sigue al cubo.
- Desde el nivel 3 incluyen parejas llave/puerta, y cada puerta es imprescindible (convertida en muro, el nivel no tendría solución). Los niveles 4 y 7 tienen un power up de velocidad y el 9 tres seguidos, para probar la acumulación. Hay muros destructibles en los niveles 2, 5, 7 y 10 (hay que romperlos para pasar) y en el 8 (un atajo: sin romperlo harían falta 26 giros en vez de 14).

| Nivel | Nombre | Tamaño | Forma | Parejas llave/puerta | Muros destructibles | Power ups | Giros mínimos |
|---|---|---|---|---|---|---|---|
| 1 | Primer giro | 9×5 | apaisado | — | — | — | 1 |
| 2 | El muro | 7×9 | vertical | — | 1 (3 golpes) | — | 3 |
| 3 | La llave | 11×7 | apaisado | amarilla | — | — | 5 |
| 4 | A toda prisa | 7×13 | vertical | naranja | — | 1 velocidad | 7 |
| 5 | Escombros | 13×9 | apaisado | roja | 1 (4 golpes) | — | 9 |
| 6 | Dos llaves | 9×15 | vertical | amarilla, azul | — | — | 10 |
| 7 | Salas | 15×11 | apaisado | verde, naranja | 1 (2 golpes) | 1 velocidad | 12 |
| 8 | El atajo | 11×17 | vertical | roja, azul | 1 (3 golpes, atajo) | — | 14 |
| 9 | Galerías | 17×13 | apaisado | amarilla, roja, verde | — | 3 velocidad | 16 |
| 10 | La gran travesía | 15×17 | casi cuadrado | naranja, azul, verde | 2 (2 y 5 golpes, seguidos) | — | 19 |

## 7. Menús y controles — Confirmada

### 7.1. Menú principal

- **Jugar:** abre el selector de niveles.
- **Opciones:** volumen de **efectos de sonido** y de **música** (0-100%; todavía no hay sonidos ni música, pero ya existen los canales de audio «SFX» y «Music»), **antialiasing** (activado/desactivado) e **idioma** (español o inglés). Los cambios se aplican al momento y se guardan en el dispositivo. Por defecto se usa el idioma del sistema si es español o inglés, y si no, inglés.
- **Créditos:** equipo de desarrollo, gráficos, sonido, tipografía, herramientas y licencia del motor, en una lista que se puede desplazar.

### 7.2. Selector de niveles

- Una rejilla con un botón por nivel, con su número y su nombre.
- Los niveles **bloqueados** se ven atenuados, con el texto «Bloqueado», y no se pueden pulsar. Los **completados** se marcan en verde.

### 7.3. Pausa

- El botón de **pausa** (arriba a la derecha) detiene el juego y muestra un menú con:
  - **Continuar:** reanuda la partida.
  - **Reiniciar:** vuelve a empezar el nivel.
  - **Salir:** vuelve al selector de niveles.
- En el móvil, el juego también se pausa al salir de la aplicación (por ejemplo, al recibir una llamada).

### 7.4. Controles

- **Tocar la mitad izquierda de la pantalla** gira a la izquierda y **tocar la mitad derecha** gira a la derecha (relativo al rumbo, como en el apartado 2.3).
- Toda la mitad de la pantalla es zona de toque, sin botones pequeños; cada toque cuenta como una pulsación. Tocar el botón de pausa no cuenta como giro.
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
