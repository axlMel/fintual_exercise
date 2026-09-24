#   Especificación — Portfolio Rebalancing Module
 
## Contexto
 
Ejercicio técnico de postulación (Fintual). Se pide construir un módulo de
gestión de portfolio de inversión, en Ruby, sin framework (no es una app
Rails: no hay persistencia, HTTP, ni UI).
 
## Requisitos originales (enunciado)
 
1. Construir una clase `Portfolio` que tiene una colección de `Stock`s.
2. Cada `Stock` tiene un método que recibe el último precio disponible
   ("Current Price").
3. `Portfolio` también tiene una colección de `Stock`s "allocated", que
   representa la distribución objetivo del portfolio (ej: 40% META, 60%
   AAPL).
4. Proveer un método de rebalanceo que determine qué `Stock`s se deben
   vender y cuáles comprar para que el portfolio quede balanceado según su
   allocation objetivo.
5. Documentar/comentar el código explicando el proceso de pensamiento.
6. Si se usa un LLM, se debe compartir el historial de la conversación.
## Decisiones de diseño tomadas
 
| Decisión | Razón |
|---|---|
| El precio se inyecta externamente (`stock.current_price(precio)`), no se calcula dentro de `Stock` | El enunciado asume una fuente externa de precios; separa "obtener precio" de "usar precio" |
| `rebalance` calcula pero no ejecuta; `rebalance!` sí ejecuta | Separar cálculo (puro, testeable) de efectos secundarios (mutación de estado) |
| El rebalanceo se basa en valor monetario, no en cantidad de acciones | Los % de allocation son sobre el valor total del portfolio |
| Las cantidades de acciones se redondean hacia abajo (`floor`) | No se permiten acciones fraccionarias en este ejercicio |
| Se ignoran diferencias menores a `MIN_TRADE_VALUE` | Evitar "ruido" de órdenes triviales por redondeo |
| Las allocations no pueden sumar más de 100% (tolerancia solo de punto flotante, 1e-9) | Puede quedar un % implícito sin invertir (cash); se valida al setear |
| `Portfolio` trackea `cash` explícitamente (`total_value = holdings + cash`) | Sin esto, rebalanceos sucesivos con allocation < 100% eran inestables (cada ejecución seguía vendiendo) |
| `rebalance` itera sobre la unión de `holdings` y `allocations` | Un holding sin allocation objetivo se trata como target 0% y se vende, **sujeto igual que cualquier operación al umbral `MIN_TRADE_VALUE`** (si vale menos de $1, no se genera una venta "solo para llegar a cero") |
| `Portfolio#update_price(symbol, price)` es un método público explícito | Antes, registrar el precio de un símbolo nuevo (sin holding) era un efecto secundario escondido dentro de `rebalance!` |
| `Stock` valida precio > 0 y cantidad entera ≥ 0; `add_holding` rechaza símbolos duplicados | Evitar estados de portfolio inválidos o silenciosamente incorrectos |
| El cálculo de acciones suma un epsilon relativo (`ratio * 1e-9`) antes de aplicar `floor` | `16.5 / 1.10` puede dar `14.999999999999998` en punto flotante puro. Un `round()` a decimales fijos "arreglaba" eso pero también redondeaba hacia arriba una fracción genuina (ej. `1.9999996` de una allocation `0.4999999`); el epsilon relativo distingue ruido de punto flotante (~1e-15) de una fracción de negocio real |
 
## Estructura del proyecto
 
```
fintual_practice/
├── README.md
├── Gemfile
├── lib/
│   ├── stock.rb        # clase Stock: symbol, quantity, price
│   └── portfolio.rb    # clase Portfolio: holdings, allocations, rebalance(!)
└── spec/
    └── portfolio_spec.rb
```
 
## Alcance explícito (qué NO cubre esta versión)
 
- No maneja comisiones de compra/venta.
- No maneja precios distintos entre "precio de compra" y "precio de venta"
  (spread/bid-ask).
- No persiste estado (no hay base de datos ni archivos).
- Precios de magnitud extrema (ej. cercanos a `Float::MAX`) pueden producir
  overflow o errores en el cálculo; se asume un rango de precios realista
  (acciones cotizando en dólares/centavos), no valores numéricos límite.
- El redondeo de acciones siempre es hacia abajo, nunca hacia el más
  cercano.
- No valida fondos suficientes de forma independiente. A diferencia de lo
  que se asumió en una iteración anterior, esto SÍ puede dejar `cash` en
  negativo: cada orden redondea sus acciones hacia abajo de forma
  independiente, así que una venta que redondea a 0 acciones no financia
  una compra que sí alcanza a ejecutarse (ver test dedicado en
  `portfolio_spec.rb` con un caso concreto AAPL/META). Es un comportamiento
  intencional y documentado, no un olvido.
## Qué pedir en la revisión
 
Se busca una revisión de código orientada a:
 
1. **Diseño OOP**: ¿la separación de responsabilidades entre `Stock` y
   `Portfolio` es correcta? ¿hay lógica que debería vivir en otra clase
   (ej: un `Rebalancer` o `Order` separados)?
2. **Robustez**: ¿qué edge cases no están cubiertos por los tests actuales
   (precios negativos, allocations vacías, portfolio sin holdings, etc.)?
3. **Legibilidad**: ¿los nombres de métodos y la estructura comunican bien
   la intención sin necesidad de leer los comentarios?
4. **Alternativas de diseño**: ¿conviene modelar las "órdenes" de
   compra/venta como su propia clase (`Order`) en vez de un `Hash`?
5. **Testing**: ¿faltan casos de prueba relevantes para un ejercicio de
   este tipo (ver "Alcance explícito" arriba)?
No se busca agregar features fuera del alcance original (cash, comisiones,
persistencia) salvo que la revisión considere que su ausencia es un
problema de diseño, no solo de alcance.