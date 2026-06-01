🔍 Scan4Me v5.0 - ALL4ME

Scan4Me es una herramienta de auditoría y reconocimiento de red interactiva avanzada escrita en Bash. Diseñada para pentesters y administradores de sistemas, centraliza múltiples herramientas de seguridad en una interfaz de menú intuitiva potenciada por fzf, incluyendo en esta versión un sistema inteligente de instalación y detección automática de dependencias.

⚠️ Nota: Esta herramienta requiere privilegios de root (sudo) para ejecutar los escaneos y gestionar las herramientas.

✨ Características Principales (Novedades de la v5)

🎨 Interfaz Renovada: Salida visual de alta compatibilidad en 256 colores y logo dinámico en tiempo real.

🗺️ Soporte Multi-Distro: Detección inteligente del gestor de paquetes nativo del sistema (apt, dnf, pacman o zypper).

🤖 Instalador de Dependencias Integrado: Si falta alguna herramienta, el script ofrece instalarla automáticamente o muestra una guía manual personalizada para tu distribución.

🎯 Modo Autodetección de Red Local: Si se ejecuta sin parámetros, el script activa una fase de descubrimiento de hosts mediante arp-scan y nmap -sn en la subred local, permitiendo seleccionar el objetivo interactivamente con fzf.

📚 Gestión Eficiente de SecLists: Clonación automática opcional vía GIT en el directorio HOME del usuario real en caso de no encontrarse en las rutas estándar.

📝 Control de Logs Flexible: Permite activar o desactivar en caliente el guardado de reportes en texto plano (.txt) o con el modo XML, desde el menú principal.

🛠️ Mapeo de Herramientas Actualizado:

WPScan: Ahora instalado y gestionado a través de Ruby Gems (gem) de forma nativa para mayor estabilidad.

Feroxbuster: Gestión de instalación y rutas optimizada mediante Snap.

📊 Post-Procesamiento de Reportes Automático (Kit de Writeup): Al finalizar un escaneo automático con el modo XML activo, se procesan los resultados para generar de manera automática un archivo HTML (vía xsltproc) y un reporte en Markdown estructurado (.md) ideal para documentación rápida de auditorías.

📋 Requisitos Previos y Dependencias
El script mapea e instala automáticamente los paquetes necesarios según tu sistema operativo. Las dependencias core incluyen:

fzf, nmap, whatweb, feroxbuster, wpscan, xsltproc, host y arp-scan.

El Diccionario SecLists
El script requiere la wordlist common.txt de SecLists para las funciones de fuzzing web. Buscará de forma automática en las siguientes ubicaciones (priorizando el entorno de tu usuario no-root):

$HOME/seclists/Discovery/Web-Content/common.txt

/usr/share/seclists/Discovery/Web-Content/common.txt

/snap/seclists/current/Discovery/Web-Content/common.txt

Si no lo encuentra, te ofrecerá clonarlo automáticamente mediante un clonado rápido (--depth 1).

🚀 Instalación y Uso
Clonar el repositorio
Bash
git clone https://github.com/DanSanMar/scan4me.git
cd scan4me
chmod +x scan4me.sh
Ejecución
El script debe ejecutarse siempre con privilegios elevados (sudo).

1. Modo Objetivo Definido:

Bash
sudo ./scan4me.sh <IP_O_DOMINIO>
Ejemplo para escanear una web con un subdirectorio o subdominio específico para WPScan:

Bash
sudo ./scan4me.sh 172.17.0.2 /wordpress
2. Modo Autodetección de Red (Novedad v5):

Bash
sudo ./scan4me.sh
Si se omite el argumento, el script escaneará la red local de forma pasiva/activa y desplegará un menú fzf para seleccionar el host víctima descubierto.

📖 Flujo de Trabajo del Menú Interactivo
Una vez iniciado, se despliega una interfaz gráfica en la terminal donde podrás conmutar opciones y lanzar auditorias:

Conmutadores globales (en caliente):

Cambiar Modo Guardado TXT: Activa/Desactiva el volcado del escaneo actual en la carpeta de auditoría.

Cambiar Modo Config XML: Activa/Desactiva los reportes detallados en Nmap junto con la posterior generación del Kit de Writeup (.md y .html).

Escaneo Automático Nmap (Opción 1): Realiza un descubrimiento inteligente de puertos abiertos (-p-), seguido de un análisis de versiones/scripts (-sSCV) y un escaneo específico de vulnerabilidades (--script vuln).

Submenú Nmap Avanzado (Opción 2): Menú especializado con 13 categorías preconfiguradas que incluyen evasión de Firewalls, escaneos agresivos, auditoría web técnica, enumeración SMB, NetBIOS y descubrimientos UDP profundos.

Herramientas Web (Opciones 3, 4 y 5): Lanzamiento directo de reconocimientos tecnológicos con WhatWeb, Fuzzing de extensiones críticas con Feroxbuster o auditoría de CMS con WPScan.

⚠️ Advertencias de Seguridad
Uso Ético: Esta herramienta está diseñada únicamente para auditorías de seguridad autorizadas. El escaneo de redes o sistemas sin permiso explícito es ilegal.

Ruido en la Red: Ciertas opciones del submenú avanzado (como escaneos UDP intrusivos o fuerza bruta invasiva con Feroxbuster) generan alto tráfico y alertarán con facilidad a sistemas de detección de intrusos (IDS/IPS).

📄 Licencia
Este proyecto está bajo la Licencia MIT. Consulta el archivo LICENSE para más detalles.