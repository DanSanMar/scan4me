# 🔍 Scan4Me v6.2- ALL4ME

Scan4Me es una herramienta de auditoría y reconocimiento de red interactiva avanzada escrita en Bash. Diseñada para *pentesters* y administradores de sistemas, centraliza múltiples herramientas de seguridad en una interfaz de menú intuitiva potenciada por `fzf`, incluyendo un sistema inteligente de instalación y detección automática de dependencias.

⚠️ **Nota:** Esta herramienta requiere privilegios de root (`sudo`) para ejecutar los escaneos, gestionar el entorno de red y administrar paquetes.

---

## ✨ Características Principales (+Novedades v6.0+)

* 🎨 **Interfaz Renovada:** Salida visual optimizada de alta compatibilidad en 256 colores (`xterm-256color`) y logo dinámico en tiempo real.
* 🗺️ **Soporte Multi-Distro:** Detección inteligente del gestor de paquetes nativo del sistema (`apt`, `dnf`, `pacman` o `zypper`).
* 🤖 **Instalador de Dependencias Integrado:** Si falta alguna herramienta core, el script ofrece automatizar su instalación o despliega una guía detallada personalizada para tu distribución. Incorpora parches automáticos para distribuciones específicas (como la instalación forzada del binario oficial estables de `nuclei`).
* 🎯 **Modo Autodetección de Red Local:** Al ejecutarse sin parámetros, activa una fase de descubrimiento de hosts activos ultra-veloz combinando `arp-scan` y un barrido de ping agresivo con `nmap` limitando los tiempos de timeout y controlando tasas de paquetes. Permite seleccionar el objetivo de forma interactiva con `fzf`.
* ☢️ **Módulo de Escaneo con Nuclei (Nuevo v6.0):** Submenú dedicado para lanzar el potente motor de ProjectDiscovery. Incluye perfiles de escaneo tecnológico inteligente (`-as`), filtrado por criticidad (Alta/Crítica), escaneos por etiquetas específicas (`cve`, `panel`, `tech`) y actualización automatizada de plantillas YAML.
* 🕵️‍♂️ **Módulo Inteligente de OSINT:** Submenú especializado en reconocimiento pasivo (*footprinting*) que adapta dinámicamente sus herramientas y consultas según si el objetivo es una dirección IP o un nombre de dominio (WHOIS, DNSRecon, WAFW00F, Sublist3r, Subfinder y la API de HackerTarget).
* 🌐 **Submenú Avanzado de Feroxbuster (Nuevo v6.1):** Control total de fuzzing web mediante perfiles preconfigurados: Agresivo (100 hilos), Normal (50 hilos), Profundo/Recursivo o Sigiloso (1 hilo con evasión por agentes aleatorios y límites de ratio).
* 📚 **Gestión Eficiente de SecLists:** Clonación automática opcional vía GIT en el directorio `HOME` del usuario real en caso de no encontrarse en las rutas estándar. Capacidad de conmutar automáticamente entre diccionarios web y diccionarios DNS.
* 📝 **Control de Logs Flexible:** Permite activar o desactivar en caliente el guardado de reportes en texto plano (`.txt`) o estructuras XML/JSON desde el menú principal.
* 🪟 **Módulo "Scan4Windows":** Submenú especializado para entornos Windows que incorpora auditorías SMB, NetBIOS y ejecuciones automáticas con herramientas externas dedicadas (`smbclient`, `nbtscan`, `enum4linux`).
* 📊 **Kit de Writeup Automático Mejorado:** Al finalizar el Auto-Scan inicial, procesa los resultados de Nmap, WhatWeb y Gobuster para compilar de manera automática un archivo HTML interactivo, un reporte en Markdown estructurado (`.md`) ideal para documentación, y un **Prompt Optimizado para IA** (`ia_prompt.txt`) diseñado para que un modelo de lenguaje analice la superficie de ataque y sugiera metodologías de explotación controladas.


---

## 🛠️ Mapeo y Gestión de Herramientas

* **WPScan:** Instalado y gestionado de manera nativa a través de **Ruby Gems (gem)** para garantizar una mayor estabilidad frente a otras versiones empaquetadas.
* **Feroxbuster:** Gestión de instalación y rutas optimizada mediante **Snap** o compilación manual. Soporta volcados nativos en JSON para parseos limpios.
* **Nuclei:** Verificación física multiruta en entornos virtuales e instalación forzada desde los releases estables de GitHub para corregir fallos de paquetería tradicionales.
* **OSINT Multi-Motor:** Integración combinada de múltiples herramientas pasivas externas para maximizar la recolección de subdominios y eludir las restricciones de bloqueo por scraping IP.
* **Herramientas Windows:** Integración nativa de `smbclient`, `nbtscan` y `enum4linux` para enumeraciones avanzadas del protocolo SMB y NetBIOS.

---

## 📋 Requisitos Previos y Dependencias

El script mapea e instala automáticamente las dependencias según tu sistema operativo. El conjunto completo actual incluye:

`fzf`, `nmap`, `whatweb`, `feroxbuster`, `wpscan`, `xsltproc`, `host`, `arp-scan`, `smbclient`, `nbtscan`, `enum4linux`, `gobuster`, `whois`, `dnsrecon`, `wafw00f`, `sublist3r`, `subfinder`, `curl` y `nuclei`.

### El Diccionario SecLists
El script requiere las listas de palabras de SecLists para las funciones de fuzzing web (`common.txt`) y de subdominios (`subdomains-top1million-5000.txt`). Buscará automáticamente en el entorno de tu usuario no-root y en rutas del sistema:
1. `$HOME/seclists/`
2. `/usr/share/seclists/`
3. `/snap/seclists/current/`

*Si no se detecta, el menú ofrecerá clonarlo mediante un clonado rápido (`--depth 1`).*

---

## 🚀 Instalación y Uso

### Clonar el repositorio y preparar el entorno

```bash
git clone [https://github.com/DanSanMar/scan4me.git](https://github.com/DanSanMar/scan4me.git)
cd scan4me
chmod +x scan4me.sh

### Ejecución

El script debe ejecutarse siempre con privilegios elevados (`sudo`).

#### 1. Modo Objetivo Definido

Bash

```
sudo ./scan4me.sh <IP_O_DOMINIO> [SUBDIRECTORIO]
```

Si deseas realizar un escaneo web en un CMS que no está en la raíz, puedes pasar el subdirectorio como segundo argumento.

_Ejemplo de uso:_

Bash

```
sudo ./scan4me.sh 172.17.0.2 /wordpress
```

#### 2. Modo Autodetección de Red (Si se omite el objetivo)

Bash

```
sudo ./scan4me.sh
```

Si ejecutas el script sin argumentos, iniciará una fase automática de descubrimiento en tu subred local combinando `arp-scan` y un barrido de ping con `nmap`. Al finalizar, desplegará un menú interactivo con `fzf` para que elijas cómodamente el host objetivo.

SH

## 📖 Flujo de Trabajo del Menú Interactivo

Al iniciar la herramienta, verás una interfaz en la terminal que te permite alternar configuraciones en tiempo real y lanzar diferentes vectores de auditoría mediante un menú visual con `fzf`:

### Conmutadores Globales (Modificaciones en caliente)

- **`[CAMBIAR MODO GUARDADO TXT]`**: Activa o desactiva el volcado y almacenamiento de la salida de los escaneos dentro de un archivo centralizado `.txt` en la carpeta de auditoría.
    
- **`[CAMBIAR MODO CONFIG XML]`**: Activa o desactiva la generación de reportes estructurados XML en `nmap`. Si está en `ON`, al finalizar un escaneo automático se compilará el **Kit de Writeup** (generando un archivo HTML interactivo y un resumen ejecutivo en Markdown `.md`).
    
    SH
    

### Módulos de Auditoría Disponibles

- **Escaneo Automático Nmap (Opción 1):** Realiza un descubrimiento inicial ultrarrápido de todos los puertos abiertos (`-p-`). Si no detecta nada, activa automáticamente un **segundo análisis sigiloso de evasión** (escaneando el _Top 1000_ con técnicas de fragmentación y suplantación de MAC). Tras hallar puertos válidos, ejecuta de forma secuencial la detección de servicios/versiones (`-sSCV`) y el análisis de vulnerabilidades (`--script vuln`).
    
    SH
    
- **Otras opciones con Nmap (Opción 2):** Submenú avanzado que incluye **11 modalidades** de escaneo especializado: auditorías agresivas, descubrimientos UDP (rápidos y profundos), mapeos ACK de cortafuegos y técnicas avanzadas de _bypass_ usando señuelos y tasas de transferencia controladas.
    
    SH
    
- **Herramientas Web (Opciones 3, 4 y 5):**
    
    - **WhatWeb:** Reconocimiento pasivo/activo de tecnologías, servidores y cabeceras HTTP.
        
    - **Feroxbuster:** Fuzzing web rápido y directo utilizando el diccionario _SecLists_ enfocado en extensiones críticas (`.bak`, `.zip`, `.sql`, etc.) de forma no recursiva.
        
    - **WPScan:** Auditoría agresiva y enumeración de usuarios y plugins vulnerables en plataformas WordPress.
        
- **Otras opciones - Solo Windows (Opción 6):** Submenú enfocado exclusivamente en la enumeración de entornos Microsoft. Integra scripts de `nmap` para vulnerabilidades SMB y NetBIOS, listado de recursos compartidos mediante sesiones nulas con `smbclient`, escaneos NetBIOS rápidos con `nbtscan` y análisis exhaustivos mediante `enum4linux`.
    
    SH
    

## ⚠️ Advertencias de Seguridad

- **Uso Ético:** Esta herramienta ha sido diseñada con fines estrictamente educativos y para auditorías de seguridad autorizadas. El escaneo de infraestructuras o sistemas sin una autorización explícita es ilegal y punible por la ley.
    
- **Ruido en la Red:** Ten en cuenta que varias de las opciones avanzadas (como los escaneos de vulnerabilidades masivos, las ráfagas de fuerza bruta de `feroxbuster` o los escaneos UDP intensivos) generan un volumen muy alto de tráfico, por lo que serán detectadas con facilidad por sistemas IDS/IPS o Firewalls activos.
    

## 📄 Licencia

Este proyecto está distribuido bajo la **Licencia MIT**. Siéntete libre de modificarlo, adaptarlo y compartirlo. Consulta el archivo `LICENSE` para más detalles.