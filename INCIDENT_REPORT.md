# Reporte de incidente 502/504 - WordPress Fasecolda (EC2 + Docker)

**Fecha:** 2026-01-08

## Resumen ejecutivo
- La caida fue causada por OOM (Out Of Memory) en el contenedor.
- Esto provoco la muerte de procesos (Apache/PHP), dejando a Varnish sin backend y generando 502/504.
- No es un problema de autoscaling; es capacidad/memoria + configuracion de concurrencia.

## Contexto tecnico
- Host: EC2 Ubuntu
- Contenedor: `fasecolda-wp`
- Stack: Varnish (cache/proxy) + Apache + mod_php (WordPress)

## Evidencias

### 1) OOM confirmado en eventos de Docker
Comando:
```
docker events --since 30m --filter container=fasecolda-wp
```
Salida relevante:
- `container oom` a las 16:53 y 16:55
- `container kill` y `exitCode=137` (killed por OOM)

### 2) Memoria disponible del host
Comando:
```
cat /proc/meminfo | head
```
Salida relevante:
- `MemTotal: 8031188 kB` (aprox. 8 GB RAM)

### 3) Concurrencia configurada en Apache
Comando:
```
docker exec fasecolda-wp cat /etc/apache2/mods-available/mpm_prefork.conf
```
Salida relevante:
- `MaxRequestWorkers 150`

### 4) Memoria por proceso PHP
Archivo:
- `custom-php.ini`

Salida relevante:
- `memory_limit = 1024M`

## Analisis
- Con `MaxRequestWorkers = 150` y `memory_limit = 1024M`, el consumo potencial excede ampliamente la RAM disponible.
- Bajo concurrencia, Apache/PHP alcanza el limite fisico -> OOM -> procesos muertos.
- Varnish queda sin backend y devuelve 502/504.
- Reiniciar el contenedor libera memoria y limpia procesos, por eso el servicio vuelve temporalmente.

## Conclusion
**Causa raiz:** OOM por configuracion de concurrencia y memoria no alineada con la capacidad real del EC2.

**Autoscaling no es la causa.** Puede mitigar picos, pero no corrige una configuracion que provoca OOM en cada nodo.

## Acciones recomendadas (minimas, sin aumentar recursos)
1) Bajar `MaxRequestWorkers` y `memory_limit`.
   - Propuesto para 8 GB: `MaxRequestWorkers 40`, `memory_limit 256M`.
2) Desactivar `wp-cron` por request y ejecutarlo via cron del sistema.
3) Mantener cache de Varnish y considerar rate-limit para bots si hay picos.

## Argumento para la reunion
"El incidente no fue por falta de autoscaling sino por OOM confirmado. Con 8 GB de RAM y la configuracion actual (150 workers + 1 GB por proceso), el sistema puede colapsar incluso sin un aumento extremo de trafico. Autoscaling seria una mitigacion de capacidad, pero primero debemos ajustar limites para evitar OOM en cada nodo."
