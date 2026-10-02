# Ley 8968 + Snowflake: Guia Completa de Cumplimiento

Entrenamiento paso a paso para implementar cumplimiento con la **Ley 8968 de 7 de julio de 2011** (Ley de Proteccion de la Persona frente al Tratamiento de sus Datos Personales de Costa Rica) usando recursos nativos de Snowflake. Cubre desde fundamentos legales hasta operacion completa con 9 modulos ejecutables.

---

## Que esta incluido

| Archivo | Descripcion |
|---------|-------------|
| `LEY8968_SNOW.html` | Guia interactiva con teoria, SQL ejecutable y sidebar navegable (dark mode) |
| `LEY8968_SNOW.sql` | SQL consolidado (1100+ lineas) para ejecucion directa en Snowsight |

## Modulos

| # | Modulo | Articulos Ley 8968 | Recursos Snowflake |
|---|--------|-------------------|-------------------|
| 1 | Fundamentos de la Ley 8968 | Arts. 1-5 | Vision general de la arquitectura |
| 2 | Gobernanza y RBAC | Arts. 5, 10-11 | Roles, grants, segregacion de funciones |
| 3 | Clasificacion de Datos | Arts. 3-4, 7 | `SYSTEM$CLASSIFY`, tags de sistema |
| 4 | Tags Personalizados | Arts. 5-6, 10 | Object tagging, herencia, bases legales |
| 5 | Enmascaramiento Dinamico | Art. 5 inc. 5, Art. 10 | Masking policies, tag-based masking |
| 6 | Row Access Policies | Art. 5 inc. 3, Art. 10 | RAP, limitacion de finalidad |
| 7 | Projection Policies | Art. 5 inc. 3, Art. 7, Art. 10 | Projection policies (FAIL/NULLIFY), minimizacion |
| 8 | Derechos del Titular (ARCO) | Arts. 8-9 | Stored procedures, portabilidad, anonimizacion |
| 9 | Auditoria y Cumplimiento | Arts. 10-11, 15-18, 25-28 | ACCESS_HISTORY, alertas, reportes |

## Defensa en Profundidad

El entrenamiento implementa tres capas independientes de proteccion en la misma tabla:

```
Capa 1: Row Access Policy    -> filtra FILAS (quien ve cuales registros)
Capa 2: Projection Policy    -> bloquea COLUMNAS en el output (quien ve cuales campos)
Capa 3: Masking Policy        -> transforma VALORES visibles (como aparecen los datos)
```

## Pre-requisitos

- Snowflake Enterprise Edition (o superior)
- Role `ACCOUNTADMIN` o `SYSADMIN` para configuracion inicial
- Snowsight (interfaz web) para ejecucion interactiva

## Como usar

1. **Configure las variables** al inicio del archivo SQL:
   ```sql
   SET LEY8968_USER      = '<SU_USUARIO>';
   SET LEY8968_DPO_EMAIL = '<SU_EMAIL>';
   ```

2. **Ejecute secuencialmente** cada modulo en Snowsight (Modulo 2 antes de 3, etc.)

3. **O abra el HTML** (`LEY8968_SNOW.html`) en el navegador para la guia interactiva con teoria y SQL lado a lado

## Limpieza

Para eliminar todos los objetos creados por el entrenamiento:

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS LEY8968_GOVERNANCE;
DROP DATABASE IF EXISTS EMPRESA_DEMO_CR;
DROP WAREHOUSE IF EXISTS LEY8968_TRAINING_WH;
DROP ROLE IF EXISTS LEY8968_OFICIAL_DATOS;
DROP ROLE IF EXISTS LEY8968_PRIVACY_ADMIN;
DROP ROLE IF EXISTS LEY8968_DATA_STEWARD;
DROP ROLE IF EXISTS LEY8968_ANALYST;
DROP ROLE IF EXISTS RRHH_ANALYST;
DROP ROLE IF EXISTS MARKETING_ANALYST;
DROP ROLE IF EXISTS FINANZAS_ANALYST;
DROP NOTIFICATION INTEGRATION IF EXISTS LEY8968_NOTIFICATIONS;
```

## Licencia

[MIT](LICENSE)
