# WordPress con Docker y NGINX para Despliegue en EC2

Este proyecto configura un entorno de WordPress utilizando Docker, con NGINX como proxy inverso. Está diseñado para ser construido y desplegado en una instancia de Amazon EC2, utilizando Amazon ECR (Elastic Container Registry) para el almacenamiento de la imagen de Docker.

## Arquitectura

El proyecto se compone de tres servicios principales orquestados a través de un script de despliegue:

1.  **Aplicación WordPress**: Un contenedor Docker que ejecuta una imagen personalizada de WordPress (basada en `wordpress:latest`) con `wp-cli` y otras herramientas.
2.  **Proxy Inverso NGINX**: Un contenedor NGINX que dirige el tráfico del puerto 80 al contenedor de WordPress.
3.  **Red Docker**: Una red interna (`fasecolda-net`) para la comunicación entre los contenedores.
4.  **Volumen Persistente**: Un volumen de Docker (`fasecolda-wp-data`) para garantizar que los datos de WordPress (archivos, plugins, etc.) persistan entre reinicios y actualizaciones de los contenedores.

## Prerrequisitos

Antes de comenzar, asegúrate de tener lo siguiente:

*   Una instancia de Amazon EC2 con Docker y Docker Compose instalados.
*   Credenciales de AWS (`AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`) con permisos para acceder a ECR.
*   Un repositorio en Amazon ECR para almacenar la imagen de Docker.

## Pasos para el Despliegue en EC2

Sigue estos pasos para clonar y ejecutar el proyecto en una instancia de EC2.

### 1. Clonar el Repositorio

Conéctate a tu instancia EC2 y clona este repositorio:

```bash
git clone <URL_DEL_REPOSITORIO>
cd sm001-15-worpress-fasecolda
```

### 2. Configurar las Variables de Entorno

Crea un archivo `.env` a partir del ejemplo proporcionado:

```bash
cp .env.example .env
```

Ahora, edita el archivo `.env` y completa las siguientes variables:

```env
# Credenciales de AWS
AWS_ACCESS_KEY_ID=TU_ACCESS_KEY
AWS_SECRET_ACCESS_KEY=TU_SECRET_KEY
AWS_REGION=tu-region-aws # ej. us-east-1

# Repositorio de ECR
ECR_REGISTRY=TU_ID_DE_CUENTA.dkr.ecr.tu-region-aws.amazonaws.com
ECR_REPOSITORY=nombre-de-tu-repositorio-ecr

# Configuración de la base de datos de WordPress (Producción)
WORDPRESS_DB_HOST=endpoint-de-tu-db.rds.amazonaws.com
WORDPRESS_DB_USER=usuario_de_db
WORDPRESS_DB_PASSWORD=contraseña_de_db
WORDPRESS_DB_NAME=nombre_de_la_db
```

### 3. Dar Permisos de Ejecución al Script

Asegúrate de que el script `start.sh` tenga permisos de ejecución:

```bash
chmod +x start.sh
```

### 4. Ejecutar el Script de Despliegue

El script `start.sh` automatiza todo el proceso. Ejecútalo con:

```bash
./start.sh
```

El script realizará las siguientes acciones:
1.  **Cargará** las variables de entorno desde `.env`.
2.  **Creará** una red de Docker si no existe.
3.  **Autenticará** Docker con tu registro de Amazon ECR.
4.  **Construirá** la imagen de Docker de WordPress.
5.  **Subirá** la imagen a tu repositorio de ECR.
6.  **Creará** un volumen de Docker para la persistencia de datos si no existe.
7.  **Iniciará** los contenedores de WordPress y NGINX.

### 5. Acceder a WordPress

Una vez que el script finalice, el sitio de WordPress estará disponible en la dirección IP pública de tu instancia de EC2, en el puerto 80.

```
http://<IP_PUBLICA_DE_TU_EC2>
```

## Administración de los Contenedores

Puedes usar los siguientes comandos de Docker para gestionar los contenedores:

*   **Ver logs en tiempo real**:
    ```bash
    docker logs -f fasecolda-wp
    docker logs -f fasecolda-nginx
    ```

*   **Detener los contenedores**:
    ```bash
    docker stop fasecolda-wp fasecolda-nginx
    ```

*   **Reiniciar los contenedores**:
    ```bash
    docker restart fasecolda-wp fasecolda-nginx
    ```

*   **Acceder a la terminal del contenedor de WordPress**:
    ```bash
    docker exec -it fasecolda-wp bash
    ```

## Limpieza

Para detener y eliminar los contenedores, puedes usar:

```bash
docker rm -f fasecolda-wp fasecolda-nginx
```

Si también deseas eliminar el volumen de datos (¡esto borrará todos los archivos de WordPress!), ejecuta:

```bash
docker volume rm fasecolda-wp-data
```