# 🔍 Scan4Me v5.9 - ALL4ME

Scan4Me es una herramienta de auditoría y reconocimiento de red interactiva avanzada escrita en Bash. Diseñada para *pentesters* y administradores de sistemas, centraliza múltiples herramientas de seguridad en una interfaz de menú intuitiva potenciada por `fzf`, incluyendo un sistema inteligente de instalación y detección automática de dependencias.

⚠️ **Nota:** Esta herramienta requiere privilegios de root (`sudo`) para ejecutar los escaneos, gestionar el entorno de red y administrar paquetes.

---

## ✨ Características Principales (+Novedades de la v5.9)

* 🎨 **Interfaz Renovada:** Salida visual optimizada de alta compatibilidad en 256 colores (`xterm-256color`) y logo dinámico en tiempo real.
* 🗺️ **Soporte Multi-Distro:** Detección inteligente del gestor de paquetes nativo del sistema (`apt`, `dnf`, `pacman` o `zypper`).
* 🤖 **Instalador de Dependencias Integrado:** Si falta alguna herramienta core, el script ofrece automatizar su instalación o despliega una guía detallada personalizada para tu distribución.
* 🎯 **Modo Autodetección de Red Local:** Al ejecutarse sin parámetros, activa una fase de descubrimiento de hosts activos mediante `arp-scan` y escaneo de sondeo `nmap -sn`, permitiendo seleccionar el objetivo interactivamente con `fzf`.
* 🕵️‍♂️ **Módulo Inteligente de OSINT (Nuevo v5.8):** Submenú especializado en reconocimiento pasivo (*footprinting*) que adapta dinámicamente sus herramientas y consultas según si el objetivo es una dirección IP o un nombre de dominio.
* 📚 **Gestión Eficiente de SecLists:** Clonación automática opcional vía GIT en el directorio `HOME` del usuario real en caso de no encontrarse en las rutas estándar.
* 📝 **Control de Logs Flexible:** Permitir activar o desactivar en caliente el guardado de reportes en texto plano (`.txt`) o XML desde el menú principal.
* 🪟 **Módulo "Scan4Windows" (Nuevo v5.7):** Submenú especializado para entornos Windows que incorpora auditorías SMB, NetBIOS y ejecuciones automáticas con herramientas externas dedicadas.
* 📊 **Kit de Writeup Automático:** Al finalizar un escaneo automático con el modo XML activo, se procesan los resultados para generar de manera automática un archivo HTML (vía `xsltproc`) y un reporte en Markdown estructurado (`.md`) ideal para documentación rápida de auditorías.
* 🤖 **Fuzzing Web en "Auto-scan" (Nuevo v5.9):** Añadimos al modulo inicial con Nmap un Fuzzing básico con Gobuster en caso de encontrar puertos Web abiertos y se implementa en la generación de Writeups.

---

## 🛠️ Mapeo y Gestión de Herramientas

* **WPScan:** Instalado y gestionado de manera nativa a través de **Ruby Gems (gem)** para garantizar una mayor estabilidad frente a otras versiones empaquetadas.
* **Feroxbuster:** Gestión de instalación y rutas optimizada mediante **Snap** o compilación manual.
* **OSINT Multi-Motor:** Integración combinada de múltiples herramientas pasivas externas para maximizar la recolección de subdominios y eludir las restricciones de bloqueo por scraping IP.
* **Herramientas Windows:** Integración nativa de `smbclient`, `nbtscan` y `enum4linux` para enumeraciones avanzadas del protocolo SMB y NetBIOS.

---

## 📋 Requisitos Previos y Dependencias

El script mapea e instala automáticamente las dependencias según tu sistema operativo. El conjunto completo incluye:

`fzf`, `nmap`, `whatweb`, `feroxbuster`, `wpscan`, `xsltproc`, `host`, `arp-scan`, `smbclient`, `nbtscan`, `enum4linux`, `whois`, `dnsrecon`, `wafw00f`, `sublist3r`, `subfinder` y `curl`.

### El Diccionario SecLists
El script requiere la wordlist `common.txt` de SecLists para las funciones de fuzzing web. Buscará automáticamente en el entorno de tu usuario no-root y en rutas del sistema:
1. `$HOME/seclists/Discovery/Web-Content/common.txt`
2. `/usr/share/seclists/Discovery/Web-Content/common.txt`
3. `/snap/seclists/current/Discovery/Web-Content/common.txt`

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