# Especificación — Portfolio Rebalancing Module

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
| Las allocations no pueden sumar más de 100% | Puede quedar un % implícito sin invertir (cash); se valida al setear |

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

- No maneja cash/efectivo sin invertir de forma explícita (solo queda
  implícito si las allocations suman <100%).
- No maneja comisiones de compra/venta.
- No maneja precios distintos entre "precio de compra" y "precio de venta"
  (spread/bid-ask).
- No persiste estado (no hay base de datos ni archivos).
- El redondeo de acciones siempre es hacia abajo, nunca hacia el más
  cercano.
- No valida que existan fondos suficientes para ejecutar las compras
  calculadas.

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
