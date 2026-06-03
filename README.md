Markdown
# 🔍 Scan4Me v5.5 - ALL4ME

Scan4Me es una herramienta de auditoría y reconocimiento de red interactiva avanzada escrita en Bash. Diseñada para *pentesters* y administradores de sistemas, centraliza múltiples herramientas de seguridad en una interfaz de menú intuitiva potenciada por `fzf`, incluyendo un sistema inteligente de instalación y detección automática de dependencias.

⚠️ **Nota:** Esta herramienta requiere privilegios de root (`sudo`) para ejecutar los escaneos, gestionar el entorno de red y administrar paquetes.

---

## ✨ Características Principales (+Novedades de la v5.5)

* 🎨 **Interfaz Renovada:** Salida visual optimizada de alta compatibilidad en 256 colores (`xterm-256color`) y logo dinámico en tiempo real.
* 🗺️ **Soporte Multi-Distro:** Detección inteligente del gestor de paquetes nativo del sistema (`apt`, `dnf`, `pacman` o `zypper`).
* 🤖 **Instalador de Dependencias Integrado:** Si falta alguna herramienta core, el script ofrece automatizar su instalación o despliega una guía detallada personalizada para tu distribución.
* 🎯 **Modo Autodetección de Red Local:** Al ejecutarse sin parámetros, activa una fase de descubrimiento de hosts activos mediante `arp-scan` y escaneo de sondeo `nmap -sn`, permitiendo seleccionar el objetivo interactivamente con `fzf`.
* 📚 **Gestión Eficiente de SecLists:** Clonación automática opcional vía GIT en el directorio `HOME` del usuario real en caso de no encontrarse en las rutas estándar.
* 📝 **Control de Logs Flexible:** Permite activar o desactivar en caliente el guardado de reportes en texto plano (`.txt`) o XML desde el menú principal.
* 🪟 **Módulo "Scan4Windows" (Nuevo v5.5):** Submenú especializado para entornos Windows que incorpora auditorías SMB, NetBIOS y ejecuciones automáticas con herramientas externas dedicadas.
* 📊 **Kit de Writeup Automático:** Al finalizar un escaneo automático con el modo XML activo, se procesan los resultados para generar de manera automática un archivo HTML (vía `xsltproc`) y un reporte en Markdown estructurado (`.md`) ideal para documentación rápida de auditorías.

---

## 🛠️ Mapeo y Gestión de Herramientas

* **WPScan:** Instalado y gestionado de manera nativa a través de **Ruby Gems (gem)** para garantizar una mayor estabilidad frente a otras versiones empaquetadas.
* **Feroxbuster:** Gestión de instalación y rutas optimizada mediante **Snap** o compilación manual.
* **Herramientas Windows:** Integración nativa de `smbclient`, `nbtscan` y `enum4linux` para enumeraciones avanzadas del protocolo SMB y NetBIOS.

---

## 📋 Requisitos Previos y Dependencias

El script mapea e instala automáticamente las dependencias según tu sistema operativo. El conjunto completo incluye:

`fzf`, `nmap`, `whatweb`, `feroxbuster`, `wpscan`, `xsltproc`, `host`, `arp-scan`, `smbclient`, `nbtscan`, y `enum4linux`.

### El Diccionario SecLists
El script requiere la wordlist `common.txt` de SecLists para las funciones de fuzzing web. Buscará automáticamente en el entorno de tu usuario no-root y en rutas del sistema:
1. `$HOME/seclists/Discovery/Web-Content/common.txt`
2. `/usr/share/seclists/Discovery/Web-Content/common.txt`
3. `/snap/seclists/current/Discovery/Web-Content/common.txt`

*Si no se detecta, el menú ofrecerá clonarlo mediante un clonado rápido (`--depth 1`).*

---

## 🚀 Instalación y Uso

### Clonar el repositorio
```bash
git clone [https://github.com/DanSanMar/scan4me.git](https://github.com/DanSanMar/scan4me.git)
cd scan4me
chmod +x scan4me.sh
Ejecución
El script debe ejecutarse siempre con privilegios elevados (sudo).

1. Modo Objetivo Definido
Bash
sudo ./scan4me.sh <IP_O_DOMINIO>
Ejemplo para escanear un host web definiendo un subdirectorio o subdominio específico para WPScan:

Bash
sudo ./scan4me.sh 172.17.0.2 /wordpress
2. Modo Autodetección de Red
Bash
sudo ./scan4me.sh
Si se omite el argumento, el script escaneará la red local de forma pasiva/activa y desplegará un menú interactivo en fzf para seleccionar el host víctima descubierto.

📖 Flujo de Trabajo del Menú Interactivo
Una vez iniciado, se despliega una interfaz gráfica en la terminal donde podrás conmutar opciones y lanzar auditorías:

Conmutadores Globales (en caliente):

Cambiar Modo Guardado TXT: Activa/Desactiva el volcado del escaneo actual en la carpeta de auditoría (.txt).

Cambiar Modo Config XML: Activa/Desactiva los reportes detallados en Nmap junto con la posterior generación del Kit de Writeup (.md y .html).

Escaneo Automático Nmap (Opción 1): Realiza un descubrimiento inteligente de puertos abiertos (-p-), seguido de un análisis agresivo de versiones/scripts (-sSCV) y un escaneo específico de vulnerabilidades (--script vuln). Incorpora un mecanismo automático de evasión sigilosa si el host bloquea los escaneos masivos.

Submenú Nmap Avanzado (Opción 2): Menú especializado con 11 categorías preconfiguradas que incluyen evasión de Firewalls (ACK Scan, Señuelos, fragmentación), escaneos agresivos, auditoría web técnica y descubrimientos UDP profundos.

Herramientas Web (Opciones 3, 4 y 5): Lanzamiento directo de reconocimientos tecnológicos con WhatWeb, Fuzzing de extensiones críticas con Feroxbuster o auditoría de CMS con WPScan.

Opciones específicas para Windows (Opción 6): Submenú dedicado al entorno Windows. Permite realizar auditorías de vulnerabilidades SMB (smb-vuln*), escaneos rápidos NetBIOS (nbtscan), listar recursos compartidos por sesión nula (smbclient) y una enumeración completa usando enum4linux.

⚠️ Advertencias de Seguridad
Uso Ético: Esta herramienta está diseñada únicamente para auditorías de seguridad autorizadas. El escaneo de redes o sistemas sin permiso explícito es ilegal.

Ruido en la Red: Ciertas opciones del submenú avanzado (como escaneos UDP intrusivos, auditorías Windows agresivas o fuerza bruta invasiva con Feroxbuster) generan alto tráfico y alertarán con facilidad a sistemas de detección de intrusos (IDS/IPS).

📄 Licencia
Este proyecto está bajo la Licencia MIT. Consulta el archivo LICENSE para más detalles.