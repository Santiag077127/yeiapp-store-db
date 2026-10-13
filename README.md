# yeiapp-store-db

Repositorio PostgreSQL 16 + Liquibase para Streaming Business System. Implementa el esquema MVP mediante changelogs ejecutables, sin datos de negocio iniciales.

## Fuente de diseño

La especificación normativa está en [Modelo-Fisico-PostgreSQL](../yeiapps-tienda-docs/04-Base-de-Datos/Modelo-Fisico-PostgreSQL.md); alcance, trazabilidad y decisiones están en [Alcance-MVP](../yeiapps-tienda-docs/00-Inicio/Alcance-MVP.md), [Trazabilidad-CU-BD](../yeiapps-tienda-docs/04-Base-de-Datos/Trazabilidad-CU-BD.md), [AUDITORIA-FINAL-PRE-BD](../yeiapps-tienda-docs/AUDITORIA-FINAL-PRE-BD.md) y [Decisiones-Pendientes](../yeiapps-tienda-docs/07-Desarrollo/Decisiones-Pendientes.md). El modelo sigue siendo documental.

## Implementación de migraciones

1. **Extensiones:** instalar `btree_gist` requerido por las restricciones de exclusión temporales.
2. **Esquemas:** crear `identity`, `catalog`, `inventory`, `sales` y `wallet`.
3. **Tipos:** crear solo tipos compartidos; el modelo prefiere `varchar + CHECK` para estados y motivos.
4. **Tablas base:** crea exactamente 19 tablas: seis de identidad, cinco de catálogo, tres de inventario, tres de ventas y dos de Wallet. Las FKs son `RESTRICT`.
5. **Referencias e índices:** crea después de las tablas base la FK circular `order_item.previous_subscription_id → subscription.id`, las FKs compuestas, exclusiones GiST, restricciones parciales y 26 índices de consulta.
6. **Garantías de integridad:** implementa CHECK/UNIQUE, vistas de disponibilidad, funciones y triggers para roles, ciclos de Order, inmutabilidad de auditoría/ledger/historial, saldo Wallet y mínimos diferidos de Wallet, Profile y asignación inicial. La expiración de Subscription sigue siendo derivada.
7. **DML/DCL/TCL:** permanecen vacíos: no se cargan datos de negocio ni se crean roles técnicos o bloques de recuperación sin una decisión operativa.

El changelog master incluye cuatro familias. La implementación reside en `01_ddl`; DML, DCL y TCL continúan vacíos. Los changesets no incluyen secretos en properties, changelogs ni logs.

## Configuración y alcance

Antes de operar, el despliegue recibe `store.currency_code`, `store.business_timezone` y el contrato validado de credenciales para cada Platform. Estos valores no requieren nuevas tablas ni bloquean comenzar el modelo lógico.

La especificación implementa 19 tablas MVP. Payment y compra directa de Customer están fuera del primer modelo.

## Configuración local

`docker-compose.yml` levanta PostgreSQL 16 y ofrece Liquibase bajo el perfil `tooling`. Los valores de conexión son de desarrollo; sobrescribir credenciales en entornos compartidos. `liquibase.properties.example` no contiene secretos de producción.

## Estado

🟢 Changelogs Liquibase listos para aplicar el esquema MVP sobre PostgreSQL 16. Deben ejecutarse en una base limpia con la configuración de despliegue y el contrato de credenciales definidos.
