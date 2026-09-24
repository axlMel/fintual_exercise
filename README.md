# Fintual Practice — Portfolio Axel David Flores Melgoza
 
Módulo simple (no una app Rails) que modela un portfolio de inversión y
calcula qué acciones comprar/vender para alinearlo a una distribución
objetivo.
 
## Cómo correrlo
 
```bash
bundle install
bundle exec rspec
```
 
## Estructura
 
- `lib/stock.rb` — una acción individual: símbolo, cantidad que se posee y
  precio actual (inyectado externamente vía `current_price`).
- `lib/portfolio.rb` — holdings actuales + allocation objetivo + lógica de
  rebalanceo.
- `spec/portfolio_spec.rb` — tests que documentan el comportamiento
  esperado con casos concretos.
## Decisiones de diseño
 
**¿Por qué el precio se "inyecta" y no se calcula dentro de `Stock`?**
El enunciado asume que ya existe un método que recibe el último precio
disponible, lo que sugiere que la obtención del precio (API externa, feed
en tiempo real, etc.) es responsabilidad de otra capa. `Stock` solo
almacena y usa ese dato (separación de responsabilidades).
 
**¿Por qué `rebalance` no ejecuta las órdenes directamente?**
Calcular y ejecutar son dos responsabilidades distintas. Separarlas permite
mostrarle al usuario un "preview" de las órdenes antes de confirmarlas (algo
muy relevante en una app financiera real), y hace el cálculo trivial de
testear sin efectos secundarios. `rebalance!` es la versión que sí aplica
los cambios, reutilizando `rebalance` internamente.
 
**¿Cómo se decide cuánto comprar/vender?**
El rebalanceo se hace en base a *valor* (dinero), no en cantidad de
acciones, porque los porcentajes de allocation son sobre el valor total del
portfolio. La diferencia en dinero entre "valor objetivo" y "valor actual"
se convierte a cantidad de acciones dividiendo por el precio actual, y se
redondea hacia abajo (no se permiten acciones fraccionarias).
 
**¿Qué pasa con diferencias muy pequeñas?**
Se ignoran (`MIN_TRADE_VALUE`) para no generar órdenes de comprar/vender
montos irrelevantes producto del redondeo.
 
**¿Qué pasa si las allocations no suman 100%?**
Se asume que sí deben sumar como máximo 100% (puede quedar un % implícito
en cash, sin invertir) y se valida al setearlas, para detectar errores de
configuración temprano en vez de fallar silenciosamente en el cálculo.
 
## Actualizaciones tras revisión de código
 
Después de una primera versión, se pidió una revisión de código (con
Codex) enfocada en diseño OOP, robustez y testing. Se resolvieron los
hallazgos de mayor impacto:
 
- **Cash explícito**: `Portfolio` ahora trackea `cash`. Sin esto, un
  rebalanceo con allocation < 100% era inestable: cada ejecución sucesiva
  seguía vendiendo, porque `total_value` se calculaba solo sobre holdings
  y "perdía" el valor de lo vendido. Ahora `total_value = holdings + cash`
  y el rebalanceo es idempotente (ver test "no se degrada al ejecutarse
  dos veces seguidas").
- **Holdings sin allocation objetivo se venden por completo**, en vez de
  ignorarse silenciosamente (antes solo se iteraba sobre `@allocations`,
  ahora sobre la unión con `@holdings`).
- **`Portfolio#update_price`**: método público explícito para registrar el
  precio de un símbolo que aún no se posee, antes de incluirlo en un
  rebalanceo. Reemplaza el comportamiento implícito anterior (que exigía
  crear un `Stock` con cantidad cero "a mano").
- **Validaciones**: `Stock` rechaza precios ≤ 0 y cantidades negativas o no
  enteras; `Portfolio#add_holding` rechaza símbolos duplicados en vez de
  pisarlos en silencio.
- **Tolerancia de allocation ajustada**: de un margen arbitrario (1.0001)
  a un epsilon real de punto flotante (1e-9), alineado con que `SPEC.md`
  exige que la suma no supere 100%.

## Segunda ronda de revisión
 
Una segunda pasada de revisión (también con Codex) encontró que un
comentario propio afirmaba algo falso, y algunos huecos de validación
reales:
 
- **Corrección importante**: un comentario en los tests afirmaba que
  `rebalance!` nunca podía dejar `cash` en negativo. Es falso — cada orden
  redondea sus acciones hacia abajo de forma *independiente*, así que una
  venta que redondea a 0 acciones no financia una compra que sí se
  ejecuta. Se corrigió la afirmación y se agregó un test que reproduce el
  caso concreto (acción cara que no se puede vender + acción barata que sí
  se puede comprar). Sigue fuera de alcance validar fondos suficientes —
  ahora esa decisión está documentada con el comportamiento real, no con
  una suposición incorrecta.
- **`update_price` con precio inválido** ya no deja un `Stock` a medio
  crear en el portfolio (antes insertaba el holding y recién después
  fallaba la validación del precio).
- **`Stock` rechaza `Float::INFINITY`** como precio (antes pasaba la
  validación por ser `Numeric` y positivo).
- **`adjust_quantity` exige un delta entero**, consistente con que el
  constructor ya prohibía cantidades fraccionarias.
- **Se quitó el redondeo a centavos** del valor de cada orden: ese mismo
  número se usa para mover `cash`, así que redondearlo podía "filtrar"
  valor con precios no enteros.
Se descartaron deliberadamente, por bajo impacto para este ejercicio:
renombrar variables internas (`diff_value`, `shares`, `update_price`) y
extraer clases `Order`/`Rebalancer` — quedan como mejoras identificadas
pero no priorizadas.

## Tercera ronda de revisión
 
Una tercera revisión encontró un bug real de punto flotante: al convertir
una diferencia en dinero a cantidad de acciones (`diff / price`), Ruby
(como cualquier lenguaje con `Float` IEEE-754) puede dar un resultado como
`14.999999999999998` en vez de `15.0` exacto. Como el cálculo usaba
`.floor` directo, esto truncaba una venta "completa" dejando 1 acción sin
vender — contradiciendo la garantía documentada de que un holding sin
allocation se liquida por completo en una sola llamada.
 
**Fix**: se redondea a 6 decimales (precisión de sobra para valores
monetarios) antes de aplicar `floor`, lo que absorbe el ruido de punto
flotante sin afectar el redondeo hacia abajo genuino (1.5 acciones sigue
dando 1). Ver `Portfolio#shares_for` (privado) y los tests que reproducen
los dos casos concretos que encontró la revisión.
 
No se persigue precisión arbitraria (para eso se usaría `BigDecimal` o
enteros en centavos) porque está fuera del alcance de este ejercicio;
queda documentado como límite conocido para precios de magnitud extrema.

## Cuarta ronda de revisión
 
Encontró dos cosas: el caso adversarial de redondeo (ya descrito arriba,
resuelto con el epsilon relativo) y una imprecisión de documentación —
"un holding sin allocation se vende por completo" no aclaraba que esa
venta sigue sujeta a `MIN_TRADE_VALUE` como cualquier otra operación (una
posición de $0.50 no se vende "solo para llegar a cero"). Se corrigió la
redacción en SPEC.md y en este README; el comportamiento del código ya
era el correcto, no requirió cambios.
 
Pendiente, y fuera del alcance de este código: adjuntar el historial de
esta conversación (los cuatro rounds de revisión) al repositorio antes de
postular, tal como exige el punto 6 del enunciado.

## Sobre el uso de LLMs
 
Este ejercicio fue creado por mi autoría y fue verificada su consistencia con ayuda de Codex (OpenAI) para comprobar coherencia entre el SPEC fabricado y el código escrito.
Para esclarecer lo antes mencionado y dar un mejor panorama del uso de agentes adjunto el historial completo de la conversación, según lo solicitado en el proceso de postulación.
`/conversacion.txt`
