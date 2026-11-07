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
- Se están valorando dos perspectivas de cámara:
  1. **Cenital ligeramente inclinada.**
  2. **Isométrica.**
- En el prototipo se pueden alternar ambas; **la perspectiva final no está elegida**. En vertical, la isométrica muestra el tablero bastante más pequeño.
- La animación del cubo debe mostrar claramente el vuelco entre casillas; no basta con trasladar el modelo o simular un deslizamiento.
- **Orientación de pantalla — Confirmada:** el juego se muestra en **vertical** (retrato) en el móvil.
- La cámara encuadra el tablero completo en el espacio libre entre los elementos de la interfaz, sea cual sea la proporción de la pantalla.

## 6. Niveles — Implementada en el prototipo

### 6.1. Progresión

- El juego tiene **10 niveles** de **dificultad creciente**, que se juegan en orden.
- Al llegar a la meta se muestra «¡Nivel completado!» y un botón **«Siguiente nivel»**. Tras el último nivel se indica que se han completado todos y se vuelve al primero.
- El jugador puede **reiniciar** el nivel en cualquier momento.
- El **nivel actual se guarda** en el dispositivo, de modo que al volver a abrir el juego se continúa en él.

### 6.2. Formato de los niveles

- Cada nivel se define como un **mapa de texto**: `#` pared, `.` casilla libre, `A` inicio y `B` meta, junto con el **rumbo inicial** del cubo.
- Los niveles son más altos que anchos, para aprovechar la pantalla vertical.

### 6.3. Medida de la dificultad

- La dificultad de un nivel se mide como el **mínimo número de giros** necesario para resolverlo con las reglas del apartado 2 (incluido el rebote, el descarte de giros bloqueados y la ausencia de giro en la casilla de salida).
- Ese mínimo se calcula con un **resolvedor automático** que también comprueba que todos los niveles tienen solución.
- Los niveles actuales van de **1 a 13 giros** y de **5×7 a 11×15 casillas**; a partir del nivel 6 incluyen zonas abiertas en las que importa en qué casilla exacta se gira.

| Nivel | Nombre | Tamaño | Giros mínimos |
|---|---|---|---|
| 1 | Primer giro | 5×7 | 1 |
| 2 | Ida y vuelta | 7×8 | 2 |
| 3 | Bifurcación | 7×9 | 3 |
| 4 | Serpiente | 7×9 | 5 |
| 5 | Pasillos | 9×11 | 6 |
| 6 | La plaza | 9×11 | 7 |
| 7 | Encrucijada | 9×13 | 8 |
| 8 | Rodeo | 11×13 | 9 |
| 9 | Laberinto | 11×15 | 11 |
| 10 | El gran recorrido | 11×15 | 13 |

## 7. Controles táctiles en Android — Implementada en el prototipo

- **Tocar la mitad izquierda de la pantalla** gira a la izquierda y **tocar la mitad derecha** gira a la derecha (relativo al rumbo, como en el apartado 2.3).
- Toda la mitad de la pantalla es zona de toque, sin botones pequeños; cada toque cuenta como una pulsación.
- Unas indicaciones discretas en la parte inferior («← Izquierda» y «Derecha →») se resaltan al tocar cada lado.
- Botones en pantalla para **reiniciar** el nivel y **cambiar de cámara**; tocar los botones no cuenta como giro.
- En PC se mantienen los controles de teclado (←/A, →/D, R reiniciar, C cámara) y el clic del ratón se trata como un toque.

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
- Prueba de las dos perspectivas de cámara sobre el mismo recorrido.
- Adaptación posterior a controles táctiles en Android.

## 10. Posibles ampliaciones — No aprobadas todavía

Estas ideas se mencionaron como posibilidades futuras, **no como requisitos del juego**:

- Caras del cubo con colores o símbolos.
- Casillas o puertas que reaccionen a la cara que queda apoyada sobre el suelo.
- Generación automática de laberintos resolubles *(existe una herramienta de desarrollo que la realiza; ver apartado 6.3)*.
- Validación automática de soluciones y dificultad *(cubierta por el resolvedor del apartado 6.3)*.
- ~~Niveles de complejidad creciente.~~ *Incorporado en el apartado 6.*

## 11. Decisiones pendientes

1. Elegir entre vista cenital inclinada e isométrica.
2. Definir velocidad y ritmo de los vuelcos.
3. ~~Establecer cómo se gestionan pulsaciones mientras el cubo está girando.~~ **Implementado en el prototipo:** apartado 2.7, pendiente de confirmación.
4. ~~Definir qué ocurre al encontrar una pared, un obstáculo o el borde del tablero.~~ **Decidido:** el cubo rebota y sigue en sentido contrario (apartado 2.4); los giros hacia una pared se descartan (apartado 2.5).
5. ~~Diseñar los controles táctiles concretos para Android.~~ **Implementado en el prototipo:** apartado 7, pendiente de confirmación.
6. ~~Decidir formato y creación de niveles.~~ **Implementado en el prototipo:** apartado 6, pendiente de confirmación.
7. Seleccionar el asistente de IA y su integración con Godot.
8. Elegir un nombre para el juego.

---

**Estado del proyecto:** mecánica principal definida y prototipo jugable en Android con 10 niveles; quedan por confirmar las decisiones marcadas como «Implementada en el prototipo» y las del apartado 11.
