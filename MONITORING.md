# Guía de Monitoreo - WordPress + Varnish

Esta guía te ayudará a verificar que las optimizaciones están funcionando correctamente.

## 📋 Scripts de Monitoreo Disponibles

### 1. `monitor.sh` - Monitor General en Tiempo Real
Muestra todas las métricas importantes actualizándose cada 5 segundos.

```bash
# Hacer ejecutable (solo primera vez)
chmod +x monitor.sh varnish-stats.sh apache-stats.sh

# Ejecutar monitor general
./monitor.sh

# Con intervalo personalizado (cada 2 segundos)
./monitor.sh 2
```

**Qué buscar:**
- ✅ CPU < 50% (antes estaba al 100%)
- ✅ Apache processes ≤ 10 (antes 20+)
- ✅ Cache hit rate > 70%

### 2. `varnish-stats.sh` - Estadísticas Detalladas de Varnish
Análisis completo del cache de Varnish.

```bash
./varnish-stats.sh
```

**Métricas clave:**
- **Cache Hit Rate**: Debe ser >70% idealmente >80%
- **Backend Failures**: Debe ser 0 o muy bajo
- **Memory Usage**: No debe estar al 100%

### 3. `apache-stats.sh` - Estadísticas Detalladas de Apache
Análisis de procesos y memoria de Apache.

```bash
./apache-stats.sh
```

**Métricas clave:**
- **Total Processes**: Debe ser ≤10 (configurado en MPM)
- **Average Memory**: Debe ser ~100-150MB por proceso
- **Total Memory**: Debe ser <1.5GB total

---

## 🎯 Checklist de Verificación Post-Deploy

### Paso 1: Rebuild y Deploy
```bash
# Rebuild la imagen con las nuevas configuraciones
docker build -t wordpress-fasecolda:latest .

# Detener contenedor actual
docker-compose down
# O si usas Docker directo
docker stop <container-name>

# Iniciar con nueva imagen
docker-compose up -d
# O
docker run -d --name wordpress-fasecolda wordpress-fasecolda:latest
```

### Paso 2: Esperar Warm-up (5 minutos)
Espera 5 minutos para que:
- Varnish construya su cache
- Apache estabilice sus procesos
- OPcache compile el código PHP

### Paso 3: Verificar Configuraciones Aplicadas

#### 3.1 Verificar MPM de Apache
```bash
docker exec <container-name> cat /etc/apache2/mods-available/mpm_prefork.conf
```
**Debe mostrar:**
- MaxRequestWorkers: 10
- ServerLimit: 10

#### 3.2 Verificar PHP OPcache
```bash
docker exec <container-name> php -i | grep opcache.enable
```
**Debe mostrar:**
```
opcache.enable => On => On
```

#### 3.3 Verificar Varnish Memory
```bash
docker exec <container-name> ps aux | grep varnish | grep malloc
```
**Debe mostrar:** `-s malloc,1G`

### Paso 4: Monitoreo de Baseline (30 minutos)

Ejecuta el monitor y toma nota de los valores:

```bash
./monitor.sh
```

**Anota estos valores cada 10 minutos:**

| Tiempo | CPU % | Apache Proc | Cache Hit % | Memory |
|--------|-------|-------------|-------------|---------|
| +10min |       |             |             |         |
| +20min |       |             |             |         |
| +30min |       |             |             |         |

---

## 📊 Comparación Antes vs Después

### ✅ Valores Esperados DESPUÉS de Optimizaciones

| Métrica | Antes (Problemático) | Después (Objetivo) | Tu Resultado |
|---------|---------------------|-------------------|--------------|
| CPU Usage | 90-100% | 20-50% | ___ |
| Apache Processes | 20+ | 3-10 | ___ |
| Memory per Process | 200-300MB | 100-150MB | ___ |
| Total Apache Memory | 4-6GB | 0.5-1.5GB | ___ |
| Cache Hit Rate | 40-60% | 75-90% | ___ |
| Response Time | 5-10s | 100-500ms | ___ |

### 🚨 Red Flags - Cuándo Preocuparse

❌ **CPU sigue >80%**
```bash
# Revisar qué procesos consumen CPU
docker exec <container-name> top -b -n 1

# Revisar logs de WordPress
docker logs <container-name> --tail 100
```

❌ **Apache procesos >10**
```bash
# Verificar que MPM config se aplicó
docker exec <container-name> apache2 -V | grep MPM

# Verificar archivo de configuración
./apache-stats.sh
```

❌ **Cache Hit Rate <60%**
```bash
# Verificar headers de cache
curl -I https://tu-dominio.com

# Ver qué URLs no se cachean
docker exec <container-name> varnishlog -q "VCL_call eq 'PASS'"
```

---

## 🔍 Comandos Útiles Adicionales

### Ver logs en tiempo real
```bash
# Logs de todo el contenedor
docker logs -f <container-name>

# Solo errores de Apache
docker exec <container-name> tail -f /var/log/apache2/error.log

# Varnish log (muestra cada request)
docker exec <container-name> varnishlog
```

### Verificar headers HTTP de cache
```bash
# Debe mostrar: X-Cache: HIT (después del primer request)
curl -I https://tu-dominio.com

# Request específico con detalles
curl -v https://tu-dominio.com/sample-page/
```

### Stats de Varnish en tiempo real
```bash
# Dashboard interactivo
docker exec -it <container-name> varnishstat

# Solo hit rate
docker exec <container-name> varnishstat -1 | grep cache_hit
```

### Limpiar cache de Varnish (si necesitas)
```bash
# Limpiar TODO el cache
docker exec <container-name> varnishadm "ban req.url ~ ."

# Limpiar URL específica
docker exec <container-name> varnishadm "ban req.url ~ ^/sample-page"
```

---

## 📈 Métricas de Éxito

Después de 24 horas de operación, deberías ver:

✅ **CPU promedio < 40%** (vs 100% antes)
✅ **Apache procesos promedio: 4-6** (vs 20+ antes)
✅ **Cache hit rate > 80%**
✅ **Backend failures = 0**
✅ **Tiempo de respuesta < 1s** (vs 5-10s antes)
✅ **Sin errores 502/503**

---

## 🆘 Troubleshooting

### Problema: CPU sigue alto después de optimizaciones

**Diagnóstico:**
```bash
# Ver qué consume CPU
docker exec <container-name> top -b -n 1 | head -20

# Ver procesos PHP
docker exec <container-name> ps aux | grep php
```

**Posibles causas:**
1. Plugin de WordPress pesado → Desactivar plugins uno por uno
2. Theme mal optimizado → Cambiar temporalmente a tema default
3. wp-cron sobrecargado → Deshabilitar en wp-config.php
4. Base de datos lenta → Revisar queries lentas

### Problema: Cache hit rate bajo

**Diagnóstico:**
```bash
# Ver qué URLs hacen PASS (bypass cache)
docker exec <container-name> varnishlog -q "VCL_call eq 'PASS'" | grep "req.url"

# Ver cookies que previenen cache
docker exec <container-name> varnishlog | grep Cookie
```

**Posibles causas:**
1. Muchas cookies → Aumentar reglas de limpieza de cookies
2. URLs con parámetros dinámicos → Implementar normalización
3. WordPress enviando no-cache headers → Revisar plugins

### Problema: Apache sigue creando >10 procesos

**Diagnóstico:**
```bash
# Verificar MPM activo
docker exec <container-name> apachectl -M | grep mpm

# Ver configuración cargada
docker exec <container-name> apache2ctl -S
```

**Solución:**
```bash
# Reconstruir imagen desde cero
docker build --no-cache -t wordpress-fasecolda:latest .
```

---

## 📞 Siguiente Paso

Una vez que ejecutes los scripts de monitoreo, comparte los resultados para:
- Confirmar que las optimizaciones funcionan
- Identificar si hay problemas adicionales
- Ajustar configuraciones si es necesario

**Comando rápido para obtener snapshot completo:**
```bash
echo "=== Monitor General ===" && ./monitor.sh 0 && \
echo "=== Varnish Stats ===" && ./varnish-stats.sh && \
echo "=== Apache Stats ===" && ./apache-stats.sh
```
