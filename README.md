# 🔍 Scan4Me v3.6 - ALL4ME

![Status](https://img.shields.io/badge/Status-Stable-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)
![Bash](https://img.shields.io/badge/Bash-Script-orange)
![Platform](https://img.shields.io/badge/Platform-Linux%20%2F%20Kali%20%2F%20Parrot-black)

**Scan4Me** es una herramienta de auditoría de red interactiva y automatizada escrita en Bash. Diseñada para pentesters y administradores de sistemas, combina múltiples herramientas de reconocimiento (Nmap, WhatWeb, Feroxbuster, WPscan) en una interfaz de menú intuitiva con soporte para colores, registro de logs y exportación a XML.

> ⚠️ **Nota:** Esta herramienta requiere privilegios de root (`sudo`) para ejecutar escaneos completos de red.

---

## ✨ Características Principales

- 🎨 **Interfaz Interactiva:** Menú navegable mediante `fzf` para una selección rápida de escaneos.
- 🛠️ **Multiherramienta:** Integra **Nmap**, **WhatWeb**, **Feroxbuster** y **WPscan** en un solo flujo de trabajo.
- 💾 **Registro Automático:** Genera reportes en texto plano (`.txt`) y opcionalmente en formato XML para cada escaneo.
- 🌐 **Reconocimiento Web:** Detección de tecnologías web, enumeración de directorios y escaneo de vulnerabilidades.
- 🎯 **Versatilidad:** Desde escaneos rápidos de OS/Versión hasta escaneos de puertos completos (TCP/UDP).
- 🖥️ **Visualización:** Salida coloreada y organizada en tiempo real.

---

## 📋 Requisitos Previos

Antes de ejecutar el script, asegúrate de tener instaladas las siguientes herramientas y dependencias en tu sistema (basado en Debian/Ubuntu/Kali, aunque también se puede usar snap en otras distros):

### Herramientas Obligatorias
```bash
sudo apt update
sudo apt install -y nmap fzf whatweb feroxbuster wpscan

Wordlist (SecLists)
El script requiere la wordlist common.txt de SecLists. Si no la tienes, instálala con:

# Opción A: Desde repositorios apt 
sudo apt install -y seclists
# Opción B: Desde repositorio Snap
sudo snap install seclists -y
# Opción C: Clonar manualmente
sudo git clone https://github.com/danielmiessler/SecLists /usr/share/seclists

El script buscará la wordlist en:
/usr/share/seclists/Discovery/Web-Content/common.txt
/snap/seclists/current/Discovery/Web-Content/common.txt

🚀 Instalación
Clona el repositorio:

git clone https://github.com/DanSanMar/scan4me.git
cd scan4me

Otorga permisos de ejecución:

chmod +x scan4me.sh

(Opcional) Mueve el script a tu PATH:

sudo mv scan4me.sh /usr/local/bin/scan4me

📖 Uso
La herramienta debe ejecutarse siempre con sudo.

Ejecución Básica
sudo ./scan4me.sh <TARGET_IP_OR_DOMAIN>

Ejemplos:

sudo ./scan4me.sh 192.168.1.1
sudo ./scan4me.sh example.com

Flujo de Trabajo
Verificación: El script comprobará si eres root, si las herramientas están instaladas y si el objetivo es alcanzable.
Menú Interactivo: Se desplegará un menú donde podrás seleccionar el tipo de escaneo.

Configuración XML: Puedes activar/desactivar la generación de archivos XML desde la opción 0.

Resultados: Los resultados se guardarán automáticamente en una carpeta llamada Auditoria_<TARGET> y se appendearán a un archivo Auditoria_Completa_<TARGET>.txt.

⚠️ Advertencias de Seguridad
Uso Ético: Esta herramienta está diseñada únicamente para auditorías de seguridad autorizadas. El escaneo de redes o sistemas sin permiso explícito es ilegal en muchas jurisdicciones.
Privilegios Root: Requiere ejecución como root para acceder a todas las funcionalidades de Nmap (como detección de SO y escaneos SYN).
Ruido en la Red: Algunos escaneos (especialmente UDP y brute-force con Feroxbuster) pueden generar mucho tráfico y ser detectados por sistemas IDS/IPS.

📄 Licencia
Este proyecto está bajo la Licencia MIT. Consulta el archivo LICENSE para más detalles.
