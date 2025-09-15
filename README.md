# WordPress Setup

A Docker-based WordPress configuration for a single WordPress site.

## Overview

This project sets up a WordPress site using Docker Compose, providing a complete WordPress environment with MySQL database and Apache server.

## Prerequisites

- Docker and Docker Compose installed on your system
- Basic knowledge of WordPress and Docker

## Quick Start

### Opción 1: Usando Docker Compose directamente

#### 1. Environment Setup

Create a `.env` file in the project root with the following variables:

```env
MYSQL_DATABASE=wordpress
MYSQL_USER=wordpress
MYSQL_PASSWORD=your_secure_password
MYSQL_ROOT_PASSWORD=your_root_password
```

#### 2. Start the Services

```bash
docker compose up -d
```

This will start:
- MySQL 8.0 database container
- WordPress container with Apache server

#### 3. Access WordPress

Open your browser and navigate to:
```
http://localhost:8080
```

### Opción 2: Usando Dockerfile (Recomendado)

#### 1. Build and Run

```bash
# Construir la imagen
docker build -t wordpress-fasecolda .

# Ejecutar el contenedor
docker run -d --name wordpress-app -p 8080:8080 wordpress-fasecolda
```

#### 2. Access WordPress

Open your browser and navigate to:
```
http://localhost:8080
```

### Complete WordPress Setup

1. Go to `http://localhost:8080` in your browser
2. Complete the WordPress installation wizard
3. Follow the setup wizard to configure your WordPress site

## Project Structure

```
├── docker-compose.yml    # Docker services configuration
├── Dockerfile           # Dockerfile para ejecutar con docker-compose
├── .env.example         # Environment variables template
├── .env                 # Your environment variables (create this)
└── README.md           # This file
```

## Services

### Database (MySQL 8.0)
- **Container**: `db`
- **Port**: Internal MySQL port (3306)
- **Data Persistence**: `db_data` volume
- **Authentication**: Native password plugin for WordPress compatibility

### WordPress
- **Container**: `wordpress`
- **Port**: `8080:80` (host:container)
- **Web Server**: Apache (supports .htaccess)
- **Data Persistence**: `wp_data` volume
- **Memory Limit**: 256MB

## Useful Commands

### Container Management

#### Con Docker Compose:
```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart services
docker compose restart
```

#### Con Dockerfile:
```bash
# Construir imagen
docker build -t wordpress-fasecolda .

# Ejecutar contenedor
docker run -d --name wordpress-app -p 8080:8080 wordpress-fasecolda

# Ver logs
docker logs -f wordpress-app

# Detener contenedor
docker stop wordpress-app

# Eliminar contenedor
docker rm wordpress-app
```

### WordPress Container Access
```bash
# Access WordPress container shell
docker exec -it wordpress bash

# Access database container shell
docker exec -it db bash
```

### Database Access
```bash
# Connect to MySQL from host
docker exec -it db mysql -u root -p

# Connect to WordPress database
docker exec -it db mysql -u wordpress -p wordpress
```

## WordPress Management

Once WordPress is set up, you can:

1. **Manage Content**: Create posts, pages, and media
2. **Customize Appearance**: Install and customize themes
3. **Add Functionality**: Install and configure plugins
4. **User Management**: Manage users and their roles

## Troubleshooting

### Common Issues

1. **Permission Issues**: Ensure Docker has proper permissions
2. **Port Conflicts**: Change port mapping in docker-compose.yml if 8080 is in use
3. **Database Connection**: Verify environment variables in `.env` file
4. **WordPress Not Loading**: Check container logs with `docker compose logs wordpress`

### Reset Everything
```bash
# Stop and remove containers, networks, and volumes
docker compose down -v

# Remove all data (WARNING: This will delete all WordPress data)
docker volume rm sm001-15-worpress-fasecolda_db_data sm001-15-worpress-fasecolda_wp_data
```

## Development Notes

- The WordPress installation supports `.htaccess` files for custom URL rewriting
- Database data and WordPress files are persisted using Docker volumes
- Memory limit is set to 256MB for better performance
- Uses MySQL native password authentication for WordPress compatibility

## Security Considerations

- Change default passwords in the `.env` file
- Use strong passwords for database users
- Consider using SSL certificates for production deployments
- Regularly update WordPress and plugins

## License

This project is for educational and development purposes. WordPress is licensed under GPL v2 or later.
