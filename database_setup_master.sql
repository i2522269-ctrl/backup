-- ========================================================================
-- SISTEMA INTEGRAL DE GESTIÓN Y ANÁLISIS DE DATOS (SIGAD - BOVINO)
-- VERSIÓN: BACKUP 2.0 (Arquitectura Medallion + Seguridad)
-- ========================================================================
-- Este script es la radiografía exacta de todos los cambios aplicados en vivo.
-- Sirve como "Infraestructura como Código" para crear réplicas exactas.

-- ------------------------------------------------------------------------
-- PARTE 1: REGLAS DE ORO Y SEGURIDAD ESTRICTA (ESQUEMA PÚBLICO)
-- ------------------------------------------------------------------------
-- 1.1 Constraints: Evitar datos nulos críticos en las tablas base.
ALTER TABLE public.registros_estudiantes ALTER COLUMN nombre_estudiante SET NOT NULL;
ALTER TABLE public.registro_actividades ALTER COLUMN descripcion SET NOT NULL;

-- 1.2 Seguridad: Habilitar Row Level Security (RLS) para evitar robos de bots.
ALTER TABLE public.registros_estudiantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.registro_actividades ENABLE ROW LEVEL SECURITY;

-- 1.3 Políticas: Permitir solo lecturas públicas e impedir escritura anónima.
DROP POLICY IF EXISTS "Lectura publica de estudiantes" ON public.registros_estudiantes;
DROP POLICY IF EXISTS "Lectura publica de actividades" ON public.registro_actividades;

CREATE POLICY "Permitir lectura publica a estudiantes" 
ON public.registros_estudiantes FOR SELECT TO public USING (true);

CREATE POLICY "Permitir lectura publica a actividades" 
ON public.registro_actividades FOR SELECT TO public USING (true);

-- 1.4 Rendimiento: Índices de fecha para soportar cruces Silver->Gold rapidísimos.
CREATE INDEX IF NOT EXISTS idx_fecha_registro_estudiantes ON public.registros_estudiantes(fecha_registro);
CREATE INDEX IF NOT EXISTS idx_fecha_actividades ON public.registro_actividades(fecha);

-- ------------------------------------------------------------------------
-- PARTE 2: PURGA Y LIMPIEZA PROFESIONAL (ESQUEMA GOLD)
-- ------------------------------------------------------------------------
-- Se eliminaron vistas redundantes o desoptimizadas creadas como borradores (Data Studio).
DROP VIEW IF EXISTS gold.vw_last_refresh_ds CASCADE;
DROP VIEW IF EXISTS gold.vw_produccion_diaria_ds CASCADE;
DROP VIEW IF EXISTS gold.vw_produccion_mensual_ds CASCADE;
DROP VIEW IF EXISTS gold.vw_promedio_por_animal_ds CASCADE;
DROP VIEW IF EXISTS gold.vw_top_razas_ds CASCADE;
DROP VIEW IF EXISTS gold.vw_produccion_resumen CASCADE;
DROP VIEW IF EXISTS gold.vw_produccion_por_categoria CASCADE;
DROP VIEW IF EXISTS gold.vw_produccion_diaria CASCADE;
DROP TABLE IF EXISTS gold.kpi_ganaderia_bovina CASCADE; -- Eliminada tabla vieja vacía

-- ------------------------------------------------------------------------
-- PARTE 3: CREACIÓN DE INDICADORES (KPIs) AUTOCALCULABLES (ESQUEMA GOLD)
-- ------------------------------------------------------------------------
-- Esta Materialized View extrae matemáticamente los métricos desde 5 tablas Silver.
CREATE MATERIALIZED VIEW gold.mv_kpi_ganaderia_bovina AS
SELECT 
    CURRENT_DATE AS fecha_reporte,
    'Región Junín - Proyecto SIGAD' AS region,
    
    -- Leche: Brecha entre la producción y el potencial técnico (18 Litros)
    COALESCE((SELECT ROUND(AVG(litros_leche), 2) FROM silver.produccion), 0) AS promedio_litros_leche_vaca,
    COALESCE((SELECT ROUND((18.00 - AVG(litros_leche)), 2) FROM silver.produccion), 18.00) AS brecha_produccion_litros,
    
    -- Mortalidad (Sanidad): Porcentaje de decesos sobre el hato total (Referencia 16%)
    COALESCE((SELECT ROUND((COUNT(*) FILTER (WHERE estado ILIKE '%Muerte%' OR estado ILIKE '%Muerto%')::numeric / NULLIF(COUNT(*), 0)) * 100, 2) FROM silver.animales), 0) AS tasa_mortalidad_porcentaje,
    
    -- Genética: Retraso en edad de primer parto (Referencia 38 meses)
    COALESCE((SELECT ROUND(AVG(a.edad_meses), 2) FROM silver.animales a JOIN silver.reproduccion r ON a.id_animal = r.id_animal WHERE r.exito = true), 0) AS edad_promedio_primer_parto_meses,
    
    -- Clima: % del año donde las vacas sufren estrés térmico por helada
    COALESCE((SELECT ROUND((COUNT(*) FILTER (WHERE hubo_helada = true)::numeric / NULLIF(COUNT(*), 0)) * 100, 2) FROM silver.clima), 0) AS incidencia_heladas_porcentaje,
    
    -- Economía: Pérdidas monetarias brutas (Citadas en 255 millones)
    COALESCE((SELECT ABS(SUM(margen_neto)) FROM silver.economia WHERE margen_neto < 0), 0) AS perdida_economica_anual_soles;

-- Otorgar accesos de lectura a la nueva vista
GRANT SELECT ON gold.mv_kpi_ganaderia_bovina TO public;

-- ------------------------------------------------------------------------
-- PARTE 4: AUTOMATIZADOR DEL ANALISTA (ROBOT PG_CRON)
-- ------------------------------------------------------------------------
-- Activamos cron y enrutamos ejecución diaria (a la 1:00 AM hora de servidor)
CREATE EXTENSION IF NOT EXISTS pg_cron CASCADE;

SELECT cron.schedule(
    'actualizacion_diaria_gold',
    '0 1 * * *',
    $$
    REFRESH MATERIALIZED VIEW gold.mv_kpi_ganaderia_bovina;
    REFRESH MATERIALIZED VIEW gold.kpi_clima_produccion;
    REFRESH MATERIALIZED VIEW gold.kpi_rentabilidad_raza;
    REFRESH MATERIALIZED VIEW gold.kpi_salud_costos;
    $$
);

-- ========================================================================
-- FIN DEL SCRIPT DOCUMENTAL
-- ========================================================================
