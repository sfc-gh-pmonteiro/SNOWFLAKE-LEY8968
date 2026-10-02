-- =============================================================================
-- LEY 8968 + SNOWFLAKE: GUIA COMPLETO DE CUMPLIMIENTO
-- =============================================================================
-- Ley 8968 de 7 de julio de 2011 | Snowflake Enterprise Edition+
-- Ley de Proteccion de la Persona frente al Tratamiento de sus Datos Personales
-- Archivo consolidado con los 9 modulos
--
-- INSTRUCCIONES:
--   1. Configure las 2 variables abajo con su usuario y email
--   2. Ejecute cada modulo secuencialmente (modulo 2 antes de 3, etc.)
--   3. Cada seccion puede ejecutarse individualmente en Snowsight
-- =============================================================================


-- #############################################################################
-- CONFIGURACION: sustituya los valores abajo antes de ejecutar
-- #############################################################################

SET LEY8968_USER      = '<SU_USUARIO>';          -- Ej: 'JMORA'
SET LEY8968_DPO_EMAIL = '<SU_EMAIL>';            -- Ej: 'datos@empresa.co.cr'


-- #############################################################################
-- MODULO 2: INFRAESTRUCTURA DE GOBERNANZA Y RBAC
-- Arts. 5, 10-11 Ley 8968
-- #############################################################################

-- -------------------------------------------------------------
-- 2.1: Database y Schemas de Gobernanza
-- -------------------------------------------------------------
-- Un database centralizado evita fragmentacion de politicas

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS LEY8968_GOVERNANCE
  COMMENT = 'Database centralizado para gobernanza Ley 8968 Costa Rica';

CREATE SCHEMA IF NOT EXISTS LEY8968_GOVERNANCE.TAGS
  COMMENT = 'Tags customizados para clasificacion Ley 8968';

CREATE SCHEMA IF NOT EXISTS LEY8968_GOVERNANCE.POLICIES
  COMMENT = 'Masking policies y Row Access Policies';

CREATE SCHEMA IF NOT EXISTS LEY8968_GOVERNANCE.AUDIT
  COMMENT = 'Logs de ARCO, procedimientos y alertas';

-- Warehouse dedicado para el entrenamiento (X-Small = costo minimo)
CREATE WAREHOUSE IF NOT EXISTS LEY8968_TRAINING_WH
  WAREHOUSE_SIZE = 'X-SMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  COMMENT = 'Warehouse dedicado para entrenamiento Ley 8968';


-- -------------------------------------------------------------
-- 2.2: Roles Ley 8968
-- -------------------------------------------------------------
-- Segregacion de funciones conforme Arts. 10-11 de la Ley 8968

USE ROLE USERADMIN;

-- Oficial de Proteccion de Datos - Art. 10
CREATE ROLE IF NOT EXISTS LEY8968_OFICIAL_DATOS
  COMMENT = 'Oficial de Proteccion de Datos - Art. 10 Ley 8968';

-- Administrador de Privacidad - crea y gestiona politicas
CREATE ROLE IF NOT EXISTS LEY8968_PRIVACY_ADMIN
  COMMENT = 'Crea y gestiona masking policies y row access policies';

-- Data Steward - aplica tags y monitorea
CREATE ROLE IF NOT EXISTS LEY8968_DATA_STEWARD
  COMMENT = 'Aplica tags Ley 8968 y monitorea cumplimiento';

-- Analista - acceso restringido a datos enmascarados
CREATE ROLE IF NOT EXISTS LEY8968_ANALYST
  COMMENT = 'Acceso a datos con enmascaramiento aplicado';

-- Jerarquia de roles
GRANT ROLE LEY8968_PRIVACY_ADMIN TO ROLE LEY8968_OFICIAL_DATOS;
GRANT ROLE LEY8968_DATA_STEWARD  TO ROLE LEY8968_OFICIAL_DATOS;
GRANT ROLE LEY8968_ANALYST       TO ROLE LEY8968_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 2.3: Privilegios de gobernanza
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Privilegios para LEY8968_DATA_STEWARD (tags)
GRANT USAGE ON DATABASE LEY8968_GOVERNANCE TO ROLE LEY8968_DATA_STEWARD;
GRANT USAGE ON SCHEMA LEY8968_GOVERNANCE.TAGS TO ROLE LEY8968_DATA_STEWARD;
GRANT CREATE TAG ON SCHEMA LEY8968_GOVERNANCE.TAGS TO ROLE LEY8968_DATA_STEWARD;
GRANT APPLY TAG ON ACCOUNT TO ROLE LEY8968_DATA_STEWARD;

-- Privilegios para LEY8968_PRIVACY_ADMIN (policies)
GRANT USAGE ON DATABASE LEY8968_GOVERNANCE TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT USAGE ON ALL SCHEMAS IN DATABASE LEY8968_GOVERNANCE TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT CREATE MASKING POLICY ON SCHEMA LEY8968_GOVERNANCE.POLICIES
  TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT CREATE ROW ACCESS POLICY ON SCHEMA LEY8968_GOVERNANCE.POLICIES
  TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LEY8968_GOVERNANCE.POLICIES
  TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LEY8968_PRIVACY_ADMIN;

-- Privilegios para LEY8968_OFICIAL_DATOS (acceso al Governance Dashboard)
GRANT DATABASE ROLE SNOWFLAKE.GOVERNANCE_VIEWER TO ROLE LEY8968_OFICIAL_DATOS;
GRANT DATABASE ROLE SNOWFLAKE.OBJECT_VIEWER TO ROLE LEY8968_OFICIAL_DATOS;

-- Asignar role LEY8968_OFICIAL_DATOS al usuario de entrenamiento
GRANT ROLE LEY8968_OFICIAL_DATOS TO USER IDENTIFIER($LEY8968_USER);

-- Warehouse: sin esto, ningun role Ley 8968 puede ejecutar queries
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE LEY8968_OFICIAL_DATOS;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE LEY8968_DATA_STEWARD;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE LEY8968_ANALYST;

-- LEY8968_OFICIAL_DATOS: acceso al AUDIT schema para ARCO
GRANT USAGE ON SCHEMA LEY8968_GOVERNANCE.AUDIT TO ROLE LEY8968_OFICIAL_DATOS;
GRANT CREATE TABLE ON SCHEMA LEY8968_GOVERNANCE.AUDIT TO ROLE LEY8968_OFICIAL_DATOS;
GRANT CREATE PROCEDURE ON SCHEMA LEY8968_GOVERNANCE.AUDIT TO ROLE LEY8968_OFICIAL_DATOS;
GRANT CREATE ALERT ON SCHEMA LEY8968_GOVERNANCE.AUDIT TO ROLE LEY8968_OFICIAL_DATOS;
GRANT EXECUTE ALERT ON ACCOUNT TO ROLE LEY8968_OFICIAL_DATOS;

-- LEY8968_PRIVACY_ADMIN: CREATE TABLE para tabla ACCESS_MAPPING (Modulo 6)
GRANT CREATE TABLE ON SCHEMA LEY8968_GOVERNANCE.POLICIES
  TO ROLE LEY8968_PRIVACY_ADMIN;


-- #############################################################################
-- MODULO 3: DESCUBRIMIENTO Y CLASIFICACION DE DATOS
-- Arts. 3-4, 7
-- #############################################################################

-- -------------------------------------------------------------
-- 3.1: Tabla de ejemplo con datos personales costarricenses
-- -------------------------------------------------------------

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS EMPRESA_DEMO_CR;
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE LEY8968_ANALYST;
CREATE SCHEMA IF NOT EXISTS EMPRESA_DEMO_CR.DATOS_CLIENTES;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE LEY8968_ANALYST;

CREATE OR REPLACE TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES (
  ID              NUMBER AUTOINCREMENT PRIMARY KEY,
  NOMBRE          STRING    COMMENT 'Nombre completo del titular',
  CEDULA          STRING    COMMENT 'Cedula de identidad costarricense',
  EMAIL           STRING    COMMENT 'Direccion de correo electronico',
  TELEFONO        STRING    COMMENT 'Telefono movil con codigo de pais',
  FECHA_NACIMIENTO DATE     COMMENT 'Fecha de nacimiento',
  DIRECCION       STRING    COMMENT 'Direccion residencial',
  DISTRITO        STRING    COMMENT 'Distrito de residencia',
  CANTON          STRING    COMMENT 'Canton de residencia',
  PROVINCIA       STRING    COMMENT 'Provincia de residencia',
  GENERO          STRING    COMMENT 'Dato sensible (Art. 3 inc. 4)',
  ETNIA           STRING    COMMENT 'Dato sensible (Art. 3 inc. 4)',
  DEPARTAMENTO    STRING    COMMENT 'Departamento interno',
  FECHA_REGISTRO  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

GRANT SELECT ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES TO ROLE LEY8968_ANALYST;

-- Insertar datos ficticios para demostracion
INSERT INTO EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
  (NOMBRE, CEDULA, EMAIL, TELEFONO, FECHA_NACIMIENTO, DIRECCION, DISTRITO, CANTON, PROVINCIA, GENERO, ETNIA, DEPARTAMENTO)
VALUES
  ('Maria Fernanda Mora',  '1-1234-5678', 'maria.mora@email.co.cr',    '+506 8123-4567', '1990-03-15', 'Barrio Escalante, Casa 24',      'Carmen',     'San Jose',      'San Jose',     'Femenino',  'Mestiza',          'RRHH'),
  ('Carlos Eduardo Solis', '2-5678-9012', 'carlos.solis@email.co.cr',  '+506 8234-5678', '1985-07-22', 'Residencial Los Arcos, Apt 5B',  'San Pedro',  'Montes de Oca', 'San Jose',     'Masculino', 'Blanca',           'FINANZAS'),
  ('Ana Patricia Vargas',  '3-2345-6789', 'ana.vargas@email.co.cr',    '+506 8345-6789', '1992-11-08', 'Urbanizacion La Valencia, #12',  'Liberia',    'Liberia',       'Guanacaste',   'Femenino',  'Afrodescendiente', 'MARKETING'),
  ('Jose Luis Jimenez',    '1-8901-2345', 'jose.j@empresa.co.cr',      '+506 8456-7890', '1988-01-30', 'Barrio Los Angeles, Casa 8',     'Heredia',    'Heredia',       'Heredia',      'Masculino', 'Blanca',           'RRHH'),
  ('Sofia Elena Castro',   '4-0123-4567', 'sofia.castro@empresa.co.cr', '+506 8567-8901', '1995-06-12', 'Condominio Montezuma, Torre 2',  'Cartago',    'Cartago',       'Cartago',      'Femenino',  'Mestiza',          'FINANZAS');


-- -------------------------------------------------------------
-- 3.1b: Grants cross-DB (dependen de EMPRESA_DEMO_CR existir)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- Acceso cross-DB para aplicar tags/policies en tablas de negocio
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE LEY8968_DATA_STEWARD;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE LEY8968_DATA_STEWARD;
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT SELECT ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
  TO ROLE LEY8968_PRIVACY_ADMIN;

-- LEY8968_OFICIAL_DATOS: DML para procedimientos ARCO
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE LEY8968_OFICIAL_DATOS;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE LEY8968_OFICIAL_DATOS;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES TO ROLE LEY8968_OFICIAL_DATOS;
GRANT CREATE STAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE LEY8968_OFICIAL_DATOS;


-- -------------------------------------------------------------
-- 3.2: Clasificacion automatica de datos
-- -------------------------------------------------------------
-- IMPORTANTE: Requiere ACCOUNTADMIN para ejecutar con auto_tag

USE ROLE ACCOUNTADMIN;

CALL SYSTEM$CLASSIFY(
  'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES',
  {'auto_tag': true}
);


-- -------------------------------------------------------------
-- 3.3: Revisar tags de sistema aplicados
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO_CR.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_NAME IN ('SEMANTIC_CATEGORY', 'PRIVACY_CATEGORY')
ORDER BY COLUMN_NAME, TAG_NAME;


-- #############################################################################
-- MODULO 4: TAGS PERSONALIZADOS PARA LEY 8968
-- Arts. 5-6, 10
-- #############################################################################

-- -------------------------------------------------------------
-- 4.1: Tags personalizados Ley 8968
-- -------------------------------------------------------------

USE ROLE LEY8968_DATA_STEWARD;
USE SCHEMA LEY8968_GOVERNANCE.TAGS;

-- Categoria del dato conforme Ley 8968 Art. 3
CREATE OR REPLACE TAG LEY8968_DATA_CATEGORY
  ALLOWED_VALUES
    'DATO_PERSONAL',
    'DATO_SENSIBLE',
    'DATO_ACCESO_IRRESTRICTO',
    'DATO_ANONIMIZADO',
    'NO_PERSONAL'
  COMMENT = 'Clasificacion del dato conforme Art. 3 de la Ley 8968';

-- Base legal para el tratamiento (Arts. 5-6)
CREATE OR REPLACE TAG LEY8968_BASE_LEGAL
  ALLOWED_VALUES
    'CONSENTIMIENTO',
    'OBLIGACION_LEGAL',
    'INTERES_VITAL',
    'INTERES_PUBLICO',
    'RELACION_CONTRACTUAL',
    'INTERES_LEGITIMO'
  COMMENT = 'Base legal para tratamiento conforme Arts. 5-6 de la Ley 8968';

-- Finalidad del tratamiento (Art. 5, principio de calidad)
CREATE OR REPLACE TAG LEY8968_FINALIDAD
  COMMENT = 'Descripcion de la finalidad del tratamiento (Art. 5, principio de calidad)';

-- Periodo de retencion en dias (Art. 6)
CREATE OR REPLACE TAG LEY8968_RETENCION
  COMMENT = 'Periodo de retencion en dias (Art. 6)';

-- Responsable de la base de datos (Art. 3 inc. 5)
CREATE OR REPLACE TAG LEY8968_RESPONSABLE
  COMMENT = 'Nombre del responsable de la base de datos (Art. 3 inc. 5)';

-- Encargado de la base de datos (Art. 3 inc. 6)
CREATE OR REPLACE TAG LEY8968_ENCARGADO
  COMMENT = 'Nombre del encargado de la base de datos (Art. 3 inc. 6)';


-- -------------------------------------------------------------
-- 4.2: Aplicar tags en la tabla
-- -------------------------------------------------------------
-- NOTA: LEY8968_DATA_CATEGORY se aplica por COLUMNA (no en la tabla)
-- para evitar conflicto con tag-based masking en columnas no-PII
-- como DEPARTAMENTO (usado por la Row Access Policy en Modulo 6).

-- Tags de metadatos a nivel de tabla (herencia para todas las columnas)
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES SET TAG
  LEY8968_GOVERNANCE.TAGS.LEY8968_BASE_LEGAL    = 'CONSENTIMIENTO',
  LEY8968_GOVERNANCE.TAGS.LEY8968_FINALIDAD     = 'Registro de clientes para prestacion de servicios',
  LEY8968_GOVERNANCE.TAGS.LEY8968_RETENCION     = '1825',
  LEY8968_GOVERNANCE.TAGS.LEY8968_RESPONSABLE   = 'Empresa Demo Costa Rica S.A.';

-- LEY8968_DATA_CATEGORY aplicado individualmente en las columnas PII
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  NOMBRE SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  CEDULA SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONO SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  FECHA_NACIMIENTO SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DIRECCION SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_PERSONAL';


-- -------------------------------------------------------------
-- 4.3: Override a nivel de columna para datos sensibles
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_SENSIBLE';

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY = 'DATO_SENSIBLE';


-- -------------------------------------------------------------
-- 4.4: Verificar tags aplicados
-- -------------------------------------------------------------

SELECT *
FROM TABLE(
  EMPRESA_DEMO_CR.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES', 'TABLE'
  )
)
WHERE TAG_DATABASE = 'LEY8968_GOVERNANCE'
ORDER BY COLUMN_NAME, TAG_NAME;

SELECT SYSTEM$GET_TAG(
  'LEY8968_GOVERNANCE.TAGS.LEY8968_BASE_LEGAL',
  'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES',
  'TABLE'
);


-- #############################################################################
-- MODULO 5: POLITICAS DE ENMASCARAMIENTO DINAMICO
-- Art. 5 inc. 5, Art. 10 Ley 8968
-- #############################################################################

-- -------------------------------------------------------------
-- 5.1a: Masking Policy para Cedula
-- -------------------------------------------------------------
-- Formato CR: 1-1234-5678 -> 1-****-****

USE ROLE LEY8968_PRIVACY_ADMIN;

CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_CEDULA
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN') THEN val
    ELSE CONCAT(
      LEFT(val, POSITION('-' IN val)),
      '****-****'
    )
  END
  COMMENT = 'Enmascara cedula para roles no autorizados (Art. 5, seguridad de los datos)';


-- -------------------------------------------------------------
-- 5.1b: Masking Policy para Email
-- -------------------------------------------------------------
-- ana.vargas@email.co.cr -> *****@email.co.cr

CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_EMAIL
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN') THEN val
    ELSE REGEXP_REPLACE(val, '.+\\@', '*****@')
  END
  COMMENT = 'Enmascara parte local del email (Art. 5, seguridad)';


-- -------------------------------------------------------------
-- 5.1c: Masking Policy para Telefono
-- -------------------------------------------------------------
-- +506 8123-4567 -> +506 ****-4567

CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PHONE
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    ELSE CONCAT('+506 ****-', RIGHT(val, 4))
  END
  COMMENT = 'Enmascara telefono conservando ultimos 4 digitos';


-- -------------------------------------------------------------
-- 5.1d: Masking Policies genericas
-- -------------------------------------------------------------

-- STRING generico (nombres, direcciones, datos sensibles)
CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_STRING
  AS (val STRING) RETURNS STRING ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    WHEN IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN') THEN val
    ELSE '***PROTEGIDO***'
  END
  COMMENT = 'Enmascaramiento generico para strings con datos personales';

-- NUMBER generico (edad, salario, etc.)
CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_NUMBER
  AS (val NUMBER) RETURNS NUMBER ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    ELSE NULL
  END
  COMMENT = 'Enmascaramiento generico para numeros con datos personales';

-- DATE generico (fecha de nacimiento, etc.)
CREATE OR REPLACE MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_DATE
  AS (val DATE) RETURNS DATE ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS') THEN val
    ELSE DATE_FROM_PARTS(1900, 01, 01)
  END
  COMMENT = 'Enmascaramiento generico para fechas con datos personales';


-- -------------------------------------------------------------
-- 5.2: Aplicar masking policies directamente
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  CEDULA SET MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_CEDULA;

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  EMAIL SET MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_EMAIL;

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  TELEFONO SET MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PHONE;

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  FECHA_NACIMIENTO SET MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_DATE;


-- -------------------------------------------------------------
-- 5.3: Tag-based masking para proteccion automatica
-- -------------------------------------------------------------
-- Al asociar masking policies a un tag, TODAS las columnas
-- etiquetadas con ese tag son automaticamente protegidas.

USE ROLE LEY8968_PRIVACY_ADMIN;

ALTER TAG LEY8968_GOVERNANCE.TAGS.LEY8968_DATA_CATEGORY SET
  MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_STRING,
  MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_NUMBER,
  MASKING POLICY LEY8968_GOVERNANCE.POLICIES.MASK_PII_DATE;

-- IMPORTANTE: Policies aplicadas directamente a la columna
-- tienen PRECEDENCIA sobre tag-based masking policies.
-- Es decir, CEDULA usa MASK_CEDULA (directa), no MASK_PII_STRING (tag).


-- -------------------------------------------------------------
-- 5.4: Validacion del enmascaramiento
-- -------------------------------------------------------------
-- IMPORTANTE: Deshabilitar secondary roles para probar aisladamente.
-- Con secondary roles activos, IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS')
-- retorna TRUE incluso usando LEY8968_ANALYST, anulando el enmascaramiento.

USE SECONDARY ROLES NONE;

-- Como LEY8968_OFICIAL_DATOS: debe ver datos completos
USE ROLE LEY8968_OFICIAL_DATOS;
SELECT NOMBRE, CEDULA, EMAIL, TELEFONO, FECHA_NACIMIENTO
FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado: datos originales visibles

-- Como LEY8968_ANALYST: debe ver datos enmascarados
USE ROLE LEY8968_ANALYST;
SELECT NOMBRE, CEDULA, EMAIL, TELEFONO, FECHA_NACIMIENTO
FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
LIMIT 3;
-- Resultado esperado:
-- NOMBRE: ***PROTEGIDO***
-- CEDULA: 1-****-****
-- EMAIL: *****@email.co.cr
-- TELEFONO: +506 ****-4567
-- FECHA_NACIMIENTO: 1900-01-01

-- Restaurar secondary roles despues del test
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 6: ROW ACCESS POLICIES
-- Art. 5 inc. 3, Art. 10
-- #############################################################################

-- -------------------------------------------------------------
-- 6.0: Roles por departamento para probar la RAP
-- -------------------------------------------------------------

USE ROLE USERADMIN;

CREATE ROLE IF NOT EXISTS RRHH_ANALYST
  COMMENT = 'Analista de Recursos Humanos';
CREATE ROLE IF NOT EXISTS MARKETING_ANALYST
  COMMENT = 'Analista de Marketing';
CREATE ROLE IF NOT EXISTS FINANZAS_ANALYST
  COMMENT = 'Analista Financiero';

-- Asignar al usuario de entrenamiento para test
GRANT ROLE RRHH_ANALYST TO USER IDENTIFIER($LEY8968_USER);
GRANT ROLE MARKETING_ANALYST TO USER IDENTIFIER($LEY8968_USER);
GRANT ROLE FINANZAS_ANALYST TO USER IDENTIFIER($LEY8968_USER);

-- Conceder warehouse + acceso a tabla
USE ROLE ACCOUNTADMIN;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE RRHH_ANALYST;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE MARKETING_ANALYST;
GRANT USAGE ON WAREHOUSE LEY8968_TRAINING_WH TO ROLE FINANZAS_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE RRHH_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE MARKETING_ANALYST;
GRANT USAGE ON DATABASE EMPRESA_DEMO_CR TO ROLE FINANZAS_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE RRHH_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE MARKETING_ANALYST;
GRANT USAGE ON SCHEMA EMPRESA_DEMO_CR.DATOS_CLIENTES TO ROLE FINANZAS_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES TO ROLE RRHH_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES TO ROLE MARKETING_ANALYST;
GRANT SELECT ON TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES TO ROLE FINANZAS_ANALYST;


-- -------------------------------------------------------------
-- 6.1: Tabla de mapeo acceso x finalidad
-- -------------------------------------------------------------

USE ROLE LEY8968_PRIVACY_ADMIN;

CREATE OR REPLACE TABLE LEY8968_GOVERNANCE.POLICIES.ACCESS_MAPPING (
  ROLE_NAME       STRING   COMMENT 'Role Snowflake',
  DEPARTMENT      STRING   COMMENT 'Departamento permitido',
  ALLOWED_PURPOSE STRING   COMMENT 'Finalidad del acceso',
  REGION          STRING   COMMENT 'Region permitida'
);

INSERT INTO LEY8968_GOVERNANCE.POLICIES.ACCESS_MAPPING VALUES
  ('RRHH_ANALYST',          'RRHH',      'GESTION_PERSONAL',  'COSTA_RICA'),
  ('MARKETING_ANALYST',     'MARKETING', 'CAMPANAS',          'COSTA_RICA'),
  ('FINANZAS_ANALYST',      'FINANZAS',  'FACTURACION',       'COSTA_RICA'),
  ('LEY8968_OFICIAL_DATOS', 'ALL',       'GOBERNANZA',        'ALL'),
  ('LEY8968_PRIVACY_ADMIN', 'ALL',       'GOBERNANZA',        'ALL');


-- -------------------------------------------------------------
-- 6.2: Row Access Policy con limitacion de finalidad
-- -------------------------------------------------------------

CREATE OR REPLACE ROW ACCESS POLICY
  LEY8968_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  AS (department STRING) RETURNS BOOLEAN ->
  -- Oficial de Datos y Privacy Admin ven todo
  IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS')
  OR IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN')
  -- Otros roles: solo datos del departamento autorizado
  OR EXISTS (
    SELECT 1
    FROM LEY8968_GOVERNANCE.POLICIES.ACCESS_MAPPING am
    WHERE am.ROLE_NAME = CURRENT_ROLE()
      AND (am.DEPARTMENT = department OR am.DEPARTMENT = 'ALL')
  )
  COMMENT = 'Limita acceso por departamento conforme principio de calidad (Art. 5, inc. 3 Ley 8968)';


-- -------------------------------------------------------------
-- 6.3: Aplicar RAP a la tabla
-- -------------------------------------------------------------

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
  ADD ROW ACCESS POLICY LEY8968_GOVERNANCE.POLICIES.RAP_PURPOSE_LIMITATION
  ON (DEPARTAMENTO);


-- -------------------------------------------------------------
-- 6.4: Validacion de la RAP
-- -------------------------------------------------------------
-- Deshabilitar secondary roles para probar aisladamente

USE SECONDARY ROLES NONE;

-- Como LEY8968_OFICIAL_DATOS: debe ver TODAS las filas
USE ROLE LEY8968_OFICIAL_DATOS;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 5 registros (todos los departamentos)

-- Como RRHH_ANALYST: debe ver solo departamento RRHH
USE ROLE RRHH_ANALYST;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Maria Fernanda Mora y Jose Luis Jimenez - ambos RRHH)

-- Como FINANZAS_ANALYST: debe ver solo FINANZAS
USE ROLE FINANZAS_ANALYST;
SELECT NOMBRE, DEPARTAMENTO FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES;
-- Resultado: 2 registros (Carlos Eduardo Solis y Sofia Elena Castro)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- #############################################################################
-- MODULO 7: POLITICAS DE PROYECCION (PROJECTION POLICIES)
-- Art. 5 inc. 3, Art. 7, Art. 10
-- #############################################################################
-- Projection Policies controlan si una columna puede APARECER en el resultado
-- final de un query. Diferente del masking (que transforma el valor), la
-- projection policy IMPIDE que la columna sea proyectada.
--
-- Orden de evaluacion: RAP (filas) -> Projection (columnas) -> Masking (valores)
--
-- Ley 8968: Implementa calidad/minimizacion (Art. 5, inc. 3) y proteccion extra
-- para datos sensibles (Art. 7).

-- -------------------------------------------------------------
-- 7.1: Grants para Projection Policies
-- -------------------------------------------------------------
-- NOTA: Estos grants tambien constan en Modulo 2 para ejecucion
-- secuencial completa. Repetidos aqui para ejecucion independiente.

USE ROLE ACCOUNTADMIN;
GRANT CREATE PROJECTION POLICY ON SCHEMA LEY8968_GOVERNANCE.POLICIES
  TO ROLE LEY8968_PRIVACY_ADMIN;
GRANT APPLY PROJECTION POLICY ON ACCOUNT TO ROLE LEY8968_PRIVACY_ADMIN;


-- -------------------------------------------------------------
-- 7.2: Projection Policy — Bloqueo total (FAIL) para datos sensibles
-- -------------------------------------------------------------
-- Columnas GENERO y ETNIA (Art. 7 — datos sensibles):
-- Solo Oficial de Datos y PRIVACY_ADMIN pueden proyectar.
-- Otros roles: query FALLA si intentan incluir la columna en el SELECT.

USE ROLE LEY8968_PRIVACY_ADMIN;

CREATE OR REPLACE PROJECTION POLICY LEY8968_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false)
  END
  COMMENT = 'Bloquea proyeccion de datos sensibles para roles no autorizados (Art. 7 Ley 8968)';


-- -------------------------------------------------------------
-- 7.3: Projection Policy — NULLIFY para PII general
-- -------------------------------------------------------------
-- En vez de fallar el query, retorna NULL para la columna protegida.
-- Util cuando se desea permitir el query pero ocultar la columna.
-- Aplicaremos a DIRECCION como ejemplo de minimizacion (Art. 5, inc. 3).

CREATE OR REPLACE PROJECTION POLICY LEY8968_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY
  AS () RETURNS PROJECTION_CONSTRAINT ->
  CASE
    WHEN IS_ROLE_IN_SESSION('LEY8968_OFICIAL_DATOS')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    WHEN IS_ROLE_IN_SESSION('LEY8968_PRIVACY_ADMIN')
      THEN PROJECTION_CONSTRAINT(ALLOW => true)
    ELSE PROJECTION_CONSTRAINT(ALLOW => false, ENFORCEMENT => 'NULLIFY')
  END
  COMMENT = 'Retorna NULL para columnas PII no autorizadas — minimizacion (Art. 5, inc. 3 Ley 8968)';


-- -------------------------------------------------------------
-- 7.4: Aplicar Projection Policies a las columnas
-- -------------------------------------------------------------

-- Datos sensibles: bloqueo total (FAIL)
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  GENERO SET PROJECTION POLICY LEY8968_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  ETNIA SET PROJECTION POLICY LEY8968_GOVERNANCE.POLICIES.PROJ_SENSITIVE_BLOCK;

-- PII general: retorna NULL (NULLIFY)
ALTER TABLE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES MODIFY COLUMN
  DIRECCION SET PROJECTION POLICY LEY8968_GOVERNANCE.POLICIES.PROJ_PII_NULLIFY;


-- -------------------------------------------------------------
-- 7.5: Validacion de las Projection Policies
-- -------------------------------------------------------------
-- Deshabilitar secondary roles para probar aisladamente

USE SECONDARY ROLES NONE;

-- Como LEY8968_OFICIAL_DATOS: debe ver TODAS las columnas normalmente
USE ROLE LEY8968_OFICIAL_DATOS;
SELECT NOMBRE, GENERO, ETNIA, DIRECCION
FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: datos visibles para el Oficial de Datos

-- Como LEY8968_ANALYST: GENERO y ETNIA bloquean el query (FAIL)
USE ROLE LEY8968_ANALYST;

-- IMPORTANTE: Este query FALLA — descomente para probar:
-- SELECT GENERO FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES LIMIT 1;
-- Error: "Projection policy does not allow column projection"

-- DIRECCION retorna NULL (enforcement NULLIFY)
SELECT NOMBRE, DIRECCION FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES LIMIT 3;
-- Resultado esperado: DIRECCION = NULL en todas las filas

-- IMPORTANTE: La columna bloqueada AUN puede usarse en WHERE/JOIN!
-- La projection policy solo afecta el OUTPUT final (SELECT list).
SELECT COUNT(*) AS TOTAL
FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
WHERE GENERO IS NOT NULL;
-- Resultado: cuenta filas con GENERO no-nulo (query no falla)

-- Restaurar secondary roles
USE SECONDARY ROLES ALL;


-- -------------------------------------------------------------
-- 7.6: Verificar todas las policies en la tabla (vista consolidada)
-- -------------------------------------------------------------

USE ROLE ACCOUNTADMIN;
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO_CR.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
ORDER BY REF_COLUMN_NAME, POLICY_KIND;


-- #############################################################################
-- MODULO 8: DERECHOS DEL TITULAR (ARCO)
-- Arts. 8-9
-- #############################################################################

-- -------------------------------------------------------------
-- 8.1: Tabla de log de solicitudes ARCO
-- -------------------------------------------------------------

USE ROLE LEY8968_OFICIAL_DATOS;

CREATE OR REPLACE TABLE LEY8968_GOVERNANCE.AUDIT.ARCO_LOG (
  REQUEST_ID    STRING DEFAULT UUID_STRING(),
  REQUEST_TYPE  STRING,
  TITULAR_ID    STRING    COMMENT 'Cedula o identificador del titular',
  REQUESTED_BY  STRING DEFAULT CURRENT_USER(),
  REQUESTED_AT  TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  STATUS        STRING DEFAULT 'PENDIENTE',
  COMPLETED_AT  TIMESTAMP_LTZ,
  DETAILS       VARIANT
)
COMMENT = 'Log de solicitudes de derechos del titular (Arts. 8-9 Ley 8968)';


-- -------------------------------------------------------------
-- 8.2: Procedimiento de Acceso (Art. 8 - Derecho de Acceso)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LEY8968_GOVERNANCE.AUDIT.ARCO_ACCESS(
  TITULAR_CEDULA STRING
)
RETURNS TABLE()
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar la solicitud en el log
  INSERT INTO LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('ACCESO', :TITULAR_CEDULA, 'CONCLUIDO', CURRENT_TIMESTAMP());

  -- Retornar datos del titular
  LET rs RESULTSET := (
    SELECT ID, NOMBRE, CEDULA, EMAIL, TELEFONO, FECHA_NACIMIENTO,
           DIRECCION, DISTRITO, CANTON, PROVINCIA, FECHA_REGISTRO
    FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    WHERE CEDULA = :TITULAR_CEDULA
  );
  RETURN TABLE(rs);
END;
$$;


-- -------------------------------------------------------------
-- 8.3: Procedimiento de Rectificacion (Art. 9 - Derecho de Rectificacion)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LEY8968_GOVERNANCE.AUDIT.ARCO_CORRECTION(
  TITULAR_CEDULA STRING,
  CAMPO          STRING,
  NUEVO_VALOR    STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Registrar la solicitud (usa SELECT para OBJECT_CONSTRUCT)
  INSERT INTO LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, DETAILS)
  SELECT 'RECTIFICACION', :TITULAR_CEDULA,
     OBJECT_CONSTRUCT('campo', :CAMPO, 'nuevo_valor', :NUEVO_VALOR);

  -- Ejecutar la correccion (campos permitidos)
  IF (:CAMPO = 'EMAIL') THEN
    UPDATE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    SET EMAIL = :NUEVO_VALOR WHERE CEDULA = :TITULAR_CEDULA;
  ELSEIF (:CAMPO = 'TELEFONO') THEN
    UPDATE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    SET TELEFONO = :NUEVO_VALOR WHERE CEDULA = :TITULAR_CEDULA;
  ELSEIF (:CAMPO = 'DIRECCION') THEN
    UPDATE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    SET DIRECCION = :NUEVO_VALOR WHERE CEDULA = :TITULAR_CEDULA;
  ELSE
    RETURN 'Error: Campo no permitido para rectificacion via ARCO.';
  END IF;

  -- Actualizar status
  UPDATE LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
  SET STATUS = 'CONCLUIDO', COMPLETED_AT = CURRENT_TIMESTAMP()
  WHERE TITULAR_ID = :TITULAR_CEDULA
    AND REQUEST_TYPE = 'RECTIFICACION'
    AND STATUS = 'PENDIENTE';

  RETURN CONCAT('Campo ', :CAMPO, ' rectificado con exito para el titular ', :TITULAR_CEDULA);
END;
$$;


-- -------------------------------------------------------------
-- 8.4: Procedimiento de Cancelacion / Anonimizacion (Art. 9 - Derecho de Cancelacion)
-- -------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LEY8968_GOVERNANCE.AUDIT.ARCO_DELETE(
  TITULAR_CEDULA STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Verificar si el titular existe
  LET cnt NUMBER := (
    SELECT COUNT(*) FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    WHERE CEDULA = :TITULAR_CEDULA
  );

  IF (:cnt = 0) THEN
    RETURN 'Error: Titular no encontrado.';
  END IF;

  -- Anonimizar datos personales (mantener registro para integridad referencial)
  UPDATE EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
  SET
    NOMBRE           = 'ANONIMIZADO',
    CEDULA           = 'X-XXXX-XXXX',
    EMAIL            = CONCAT('anonimizado_', ID, '@removed.ley8968'),
    TELEFONO         = '+506 0000-0000',
    FECHA_NACIMIENTO = DATE_FROM_PARTS(1900, 01, 01),
    DIRECCION        = 'ELIMINADO',
    DISTRITO         = 'ELIMINADO',
    CANTON           = 'ELIMINADO',
    PROVINCIA        = 'XX',
    GENERO           = NULL,
    ETNIA            = NULL
  WHERE CEDULA = :TITULAR_CEDULA;

  -- Registrar en el log
  INSERT INTO LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('CANCELACION', :TITULAR_CEDULA, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Datos del titular ', :TITULAR_CEDULA, ' anonimizados con exito.');
END;
$$;


-- -------------------------------------------------------------
-- 8.5: Procedimiento de Portabilidad (Art. 8)
-- -------------------------------------------------------------

-- Crear stage para exportacion ARCO
CREATE STAGE IF NOT EXISTS EMPRESA_DEMO_CR.DATOS_CLIENTES.ARCO_EXPORT
  COMMENT = 'Stage para exportacion de datos en solicitudes de portabilidad';

CREATE OR REPLACE PROCEDURE LEY8968_GOVERNANCE.AUDIT.ARCO_PORTABILITY(
  TITULAR_CEDULA STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  -- Exportar datos a stage
  COPY INTO @EMPRESA_DEMO_CR.DATOS_CLIENTES.ARCO_EXPORT/portabilidad/
  FROM (
    SELECT ID, NOMBRE, CEDULA, EMAIL, TELEFONO, FECHA_NACIMIENTO,
           DIRECCION, DISTRITO, CANTON, PROVINCIA, FECHA_REGISTRO
    FROM EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES
    WHERE CEDULA = :TITULAR_CEDULA
  )
  FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"')
  OVERWRITE = TRUE
  SINGLE = TRUE
  HEADER = TRUE;

  -- Registrar en el log
  INSERT INTO LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
    (REQUEST_TYPE, TITULAR_ID, STATUS, COMPLETED_AT)
  VALUES
    ('PORTABILIDAD', :TITULAR_CEDULA, 'CONCLUIDO', CURRENT_TIMESTAMP());

  RETURN CONCAT('Datos exportados a @ARCO_EXPORT/portabilidad/ para el titular ', :TITULAR_CEDULA);
END;
$$;


-- -------------------------------------------------------------
-- 8.6: Validacion de los procedimientos ARCO
-- -------------------------------------------------------------

-- Test: Derecho de Acceso
CALL LEY8968_GOVERNANCE.AUDIT.ARCO_ACCESS('1-1234-5678');

-- Test: Derecho de Rectificacion
CALL LEY8968_GOVERNANCE.AUDIT.ARCO_CORRECTION(
  '1-1234-5678', 'EMAIL', 'maria.nuevo@email.co.cr'
);

-- Test: Derecho de Portabilidad
CALL LEY8968_GOVERNANCE.AUDIT.ARCO_PORTABILITY('2-5678-9012');

-- Verificar log de ARCO
SELECT * FROM LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
ORDER BY REQUESTED_AT DESC;


-- #############################################################################
-- MODULO 9: MONITOREO, AUDITORIA Y CUMPLIMIENTO
-- Arts. 10-11, 15-18, 25-28
-- #############################################################################

-- -------------------------------------------------------------
-- 9.1: Quien accedio a datos personales en los ultimos 30 dias?
-- -------------------------------------------------------------
-- Usa ACCESS_HISTORY + QUERY_HISTORY para rastrear accesos (Arts. 10-11)
-- NOTA: ACCESS_HISTORY no tiene ROLE_NAME; obtener via JOIN con QUERY_HISTORY

USE ROLE ACCOUNTADMIN;

SELECT
  ah.USER_NAME,
  qh.ROLE_NAME,
  ah.QUERY_START_TIME,
  boa.VALUE:objectName::STRING AS OBJECT_ACCESSED,
  boa.VALUE:objectDomain::STRING AS OBJECT_TYPE,
  ah.QUERY_ID
FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY ah
  JOIN SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    ON ah.QUERY_ID = qh.QUERY_ID
  ,LATERAL FLATTEN(input => ah.BASE_OBJECTS_ACCESSED) boa
WHERE ah.QUERY_START_TIME >= DATEADD('day', -30, CURRENT_TIMESTAMP())
  AND boa.VALUE:objectName::STRING ILIKE '%CLIENTES%'
ORDER BY ah.QUERY_START_TIME DESC
LIMIT 100;


-- -------------------------------------------------------------
-- 9.2: Que tablas TIENEN y cuales NO TIENEN tags Ley 8968?
-- -------------------------------------------------------------

SELECT
  t.TABLE_CATALOG AS DATABASE_NAME,
  t.TABLE_SCHEMA  AS SCHEMA_NAME,
  t.TABLE_NAME,
  t.ROW_COUNT,
  COALESCE(tr.TAG_VALUE, '*** SIN TAG ***') AS LEY8968_CATEGORY,
  CASE
    WHEN tr.TAG_VALUE IS NOT NULL THEN 'CONFORME'
    ELSE 'PENDIENTE'
  END AS STATUS_CUMPLIMIENTO
FROM SNOWFLAKE.ACCOUNT_USAGE.TABLES t
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
  ON t.TABLE_CATALOG = tr.OBJECT_DATABASE
  AND t.TABLE_SCHEMA = tr.OBJECT_SCHEMA
  AND t.TABLE_NAME = tr.OBJECT_NAME
  AND tr.TAG_NAME = 'LEY8968_DATA_CATEGORY'
  AND tr.DOMAIN = 'TABLE'
WHERE t.DELETED IS NULL
  AND t.TABLE_SCHEMA != 'INFORMATION_SCHEMA'
ORDER BY STATUS_CUMPLIMIENTO DESC, t.TABLE_CATALOG, t.TABLE_SCHEMA;


-- -------------------------------------------------------------
-- 9.3: Columnas con y sin masking policies
-- -------------------------------------------------------------

SELECT
  pr.REF_DATABASE_NAME AS DATABASE_NAME,
  pr.REF_SCHEMA_NAME   AS SCHEMA_NAME,
  pr.REF_ENTITY_NAME   AS TABLE_NAME,
  pr.REF_COLUMN_NAME   AS COLUMN_NAME,
  pr.POLICY_NAME,
  pr.POLICY_STATUS,
  COALESCE(pr.TAG_NAME, 'DIRECTA') AS APLICACION
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
WHERE pr.POLICY_KIND = 'MASKING_POLICY'
ORDER BY pr.REF_DATABASE_NAME, pr.REF_ENTITY_NAME, pr.REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.3b: Inventario de Projection Policies
-- -------------------------------------------------------------

SELECT
  pp.POLICY_NAME,
  pp.POLICY_CATALOG AS POLICY_DATABASE,
  pp.POLICY_SCHEMA,
  pp.CREATED,
  pp.POLICY_COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.PROJECTION_POLICIES pp
WHERE pp.DELETED IS NULL
ORDER BY pp.CREATED;

-- Columnas protegidas por projection policies en la tabla CLIENTES
SELECT POLICY_NAME, POLICY_KIND, REF_COLUMN_NAME, POLICY_STATUS
FROM TABLE(EMPRESA_DEMO_CR.INFORMATION_SCHEMA.POLICY_REFERENCES(
  ref_entity_name => 'EMPRESA_DEMO_CR.DATOS_CLIENTES.CLIENTES',
  ref_entity_domain => 'TABLE'
))
WHERE POLICY_KIND = 'PROJECTION_POLICY'
ORDER BY REF_COLUMN_NAME;


-- -------------------------------------------------------------
-- 9.4: Solicitudes ARCO pendientes (SLA 5 dias habiles - Art. 8)
-- -------------------------------------------------------------

USE ROLE LEY8968_OFICIAL_DATOS;

SELECT
  REQUEST_ID,
  REQUEST_TYPE,
  TITULAR_ID,
  REQUESTED_BY,
  REQUESTED_AT,
  STATUS,
  DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) AS DIAS_ABIERTO,
  CASE
    WHEN DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 5
      THEN 'ATRASADO'
    WHEN DATEDIFF('day', REQUESTED_AT, CURRENT_TIMESTAMP()) > 3
      THEN 'ATENCION'
    ELSE 'DENTRO DEL PLAZO'
  END AS SLA_STATUS
FROM LEY8968_GOVERNANCE.AUDIT.ARCO_LOG
WHERE STATUS = 'PENDIENTE'
ORDER BY REQUESTED_AT ASC;


-- -------------------------------------------------------------
-- 9.5: Alerta para accesos masivos a datos personales (Arts. 10-11 - Deberes)
-- -------------------------------------------------------------

-- Pre-requisito: crear notification integration para email
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE NOTIFICATION INTEGRATION LEY8968_NOTIFICATIONS
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ($LEY8968_DPO_EMAIL);

USE ROLE LEY8968_OFICIAL_DATOS;

CREATE OR REPLACE ALERT LEY8968_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS
  WAREHOUSE = LEY8968_TRAINING_WH
  SCHEDULE = 'USING CRON 0 */6 * * * America/Costa_Rica'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE EXECUTION_STATUS = 'SUCCESS'
      AND ROWS_PRODUCED > 10000
      AND QUERY_START_TIME >= DATEADD('hour', -6, CURRENT_TIMESTAMP())
      AND (QUERY_TEXT ILIKE '%clientes%' OR QUERY_TEXT ILIKE '%datos_personales%')
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'LEY8968_NOTIFICATIONS',
      $LEY8968_DPO_EMAIL,
      'ALERTA LEY 8968: Acceso masivo a datos personales detectado',
      'Una consulta retorno mas de 10,000 registros de tablas con datos personales en las ultimas 6 horas. Verifique el ACCESS_HISTORY para detalles.'
    );

-- Activar la alerta
ALTER ALERT LEY8968_GOVERNANCE.AUDIT.ALERT_MASS_DATA_ACCESS RESUME;


-- =============================================================================
-- FIN DEL ENTRENAMIENTO
-- =============================================================================
-- Todos los 9 modulos han sido validados.
-- Consulte el HTML (LEY8968_SNOW.html) para detalles conceptuales de cada modulo.
-- =============================================================================
