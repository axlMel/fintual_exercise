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
