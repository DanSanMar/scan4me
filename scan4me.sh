#!/usr/bin/env bash

export TERM=xterm-256color

# Colores (Cambiados a \033 para mayor compatibilidad)
BLANCO="\033[1;37m"
AZUL="\033[1;36m"
AMARILLO="\033[1;33m"
ROJO="\033[1;31m"
VERDE="\033[1;32m"
RESET="\033[0m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
#Se ha puesto directamente para evitar errores ALARMA="\e[1;5m"

# --- DETECCIÓN DE GESTOR DE PAQUETES ---
detectar_gestor() {
    if command -v apt &> /dev/null; then echo "apt"
    elif command -v dnf &> /dev/null; then echo "dnf"
    elif command -v pacman &> /dev/null; then echo "pacman"
    elif command -v zypper &> /dev/null; then echo "zypper"
    else echo "unknown"; fi
}

GESTOR=$(detectar_gestor)

# --- DEFINICIÓN DE DEPENDENCIAS ---
dependencies=(fzf nmap whatweb feroxbuster wpscan xsltproc host)


# --- MAPEO DE NOMBRES DE PAQUETES  ---
get_package_name() {
    local tool=$1
    case "$tool" in
        "xsltproc") echo "xsltproc" ;;
        "host") [[ "$GESTOR" == "apt" ]] && echo "dnsutils" || echo "bind-utils" ;;
        "feroxbuster") echo "SNAP_REQUIRED" ;;
        "wpscan") echo "GEM_REQUIRED" ;; # Cambiamos Snap por Ruby Gems
        *) echo "$tool" ;;
    esac
}

install_tools() {
    local tools_to_install=("$@")
    
    echo -e "\n${AZUL}🔄 Actualizando repositorios ($GESTOR)...${RESET}"
    case "$GESTOR" in
        "apt") sudo apt update -y ;;
        "dnf") sudo dnf makecache ;;
        "pacman") sudo pacman -Sy ;;
        "zypper") sudo zypper refresh ;;
    esac

    for tool in "${tools_to_install[@]}"; do
        pkg=$(get_package_name "$tool")

        if [[ "$pkg" == "GEM_REQUIRED" ]]; then
            echo -e "\n${AZUL}💎 Instalando $tool y dependencias de compilación para $GESTOR...${RESET}"
            
            case "$GESTOR" in
                "apt")
                    sudo apt update -y
                    sudo apt install -y ruby-full build-essential zlib1g-dev libcurl4-openssl-dev libcurl4
                    ;;
                "dnf")
                    # Equivalentes exactos para Fedora
                    sudo dnf install -y ruby ruby-devel gcc gcc-c++ make zlib-devel libcurl-devel openssl-devel
                    ;;
                *)
                    echo -e "${ROJO}⚠️ Gestor no soportado para dependencias Ruby. Intenta instalarlas manualmente.${RESET}"
                    ;;
            esac
    
            sudo ldconfig 2>/dev/null
            echo -e "${AZUL}⚙️ Instalando gema WPScan...${RESET}"
            sudo gem install wpscan
            continue
        fi

        if [[ "$pkg" == "SNAP_REQUIRED" ]]; then

            if ! command -v snap &> /dev/null; then
                echo -e "\n${AMARILLO}⚠️ $tool requiere Snap, pero no está instalado.${RESET}"
                echo -ne "${AMARILLO}¿Desea instalar snapd ahora? (s/n): ${RESET}"
                read -r snap_pref
                if [[ "$snap_pref" == "s" ]]; then
                    echo -e "\n${AZUL}📦 Instalando motor de Snap...${RESET}"
                    case "$GESTOR" in
                        "apt") 
                            sudo apt install -y snapd
                            sudo systemctl enable --now snapd.socket
                            # Enlace simbólico vital en Debian para rutas estándar
                            sudo ln -s /var/lib/snapd/snap /snap 2>/dev/null 
                            ;;
                        "dnf") sudo dnf install -y snapd && sudo systemctl enable --now snapd.socket ;;
                    esac
                    export PATH="$PATH:/snap/bin:/var/lib/snapd/snap/bin"
                    
                else
                    echo -e "${ROJO}❌ No se puede instalar $tool por falta de Snap.${RESET}"
                    continue
                fi
            fi


            echo -e "${AZUL}📦 Instalando $tool vía Snap...${RESET}"
            local classic=""
            [[ "$tool" == "feroxbuster" || "$tool" == "fzf" ]] && classic="--classic"
            sudo snap install "$tool" $classic
            export PATH=$PATH:/var/lib/snapd/snap/bin
            
        else
            echo -e "${AZUL}📦 Instalando paquete: $pkg...${RESET}"
            case "$GESTOR" in
                "apt") sudo apt install -y "$pkg" ;;
                "dnf") sudo dnf install -y "$pkg" ;;
                "pacman") sudo pacman -S --noconfirm "$pkg" ;;
                "zypper") sudo zypper install -y "$pkg" ;;
            esac
        fi
    done
}

mostrar_instrucciones() {
    clear
    echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}"
    echo -e "${BLANCO} 📖 GUÍA DE INSTALACIÓN MANUAL PARA TU SISTEMA (${GESTOR^^})${RESET}"
    echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n"

    for tool in "${missing_tools[@]}"; do
        echo -e "${AMARILLO}🛠  Herramienta: ${BLANCO}$tool${RESET}"
        case "$tool" in
            "fzf"|"nmap"|"whatweb"|"xsltproc"|"host")
                pkg=$(get_package_name "$tool")
                echo -e "   ${VERDE}✔ Estándar:${RESET} sudo $GESTOR install -y $pkg"
                ;;
            "feroxbuster")
                echo -e "   ${VERDE}✔ Snap:${RESET}      sudo snap install feroxbuster"
                echo -e "   ${VERDE}✔ Manual:${RESET}    curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/master/install-nix.sh | bash"
                ;;
            "wpscan")
                echo -e "   ${VERDE}✔ RubyGem:${RESET}   sudo gem install wpscan"
                echo -e "   ${VERDE}✔ Snap:${RESET}      sudo snap install wpscan"
                ;;
        esac
        echo -e "${AZUL}--------------------------------------------------${RESET}"
    done
    
    if [ ! -f "$wordlist_standard" ] && [ ! -f "$wordlist_snap" ]; then
        echo -e "${AMARILLO}📚 Diccionario: SecLists${RESET}"
        echo -e "   ${VERDE}✔ Git (Recomendado):${RESET} sudo git clone --depth 1 https://github.com/danielmiessler/SecLists /usr/share/seclists"
        echo -e "   ${VERDE}✔ APT (Kali/Debian):${RESET} sudo apt install seclists"
        echo -e "${AZUL}--------------------------------------------------${RESET}"
    fi
}

# --- VARIABLE DE ESTADO XML ---
xml_status="OFF"

# --- FUNCIÓN LOGO ---
function mostrar_logo() {
    clear
    echo -e "${CYAN}"
    echo "      █████╗ ██╗      ██╗      ██╗  ██╗███╗   ███╗███████╗"
    echo "     ██╔══██╗██║      ██║      ██║  ██║████╗ ████║██╔════╝"
    echo -e "${VERDE}"
    echo "     ███████║██║      ██║      ███████║██╔████╔██║█████╗  "
    echo "     ██╔══██║██║      ██║      ╚════██║██║╚██╔╝██║██╔══╝  "
    echo -e "${MAGENTA}"
    echo "     ██║  ██║███████╗███████╗      ██║██║ ╚═╝ ██║███████╗"
    echo "     ╚═╝  ╚═╝╚══════╝╚══════╝      ╚═╝╚═╝     ╚═╝╚══════╝"
    echo ""
    echo -e "${BLANCO}              ░▒▓ ALL  4  M E ▓▒░"
    echo -e "${AZUL}--[ Escaneo Interactivo de Red con multiherramientas ]--${RESET}"
    echo -e "${BLANCO}--[ Versión: 4.5 Nmap + Feroxbuster + SectList + Wpscan + Nmap Auto + Auto-install]--${RESET}"
    echo ""
}

function procesar_reportes() {
    local ultimo_xml=$(ls -t "$folder"/*.xml 2>/dev/null | head -n 1)
    [ -z "$ultimo_xml" ] && return

    local nombre_base="${ultimo_xml%.xml}"
    local archivo_nmap="${nombre_base}.nmap"
    local archivo_md="${nombre_base}_resumen.md"
    local archivo_html="${nombre_base}.html"

    # 1. HTML (Para verlo en navegador)
    xsltproc "$ultimo_xml" -o "$archivo_html"

    # 2. Markdown "MODO BRUTO"
    {
        echo "# 🛡️ Reporte de Escaneo: $target"
        echo "📅 **Fecha:** $(date '+%d-%m-%Y %H:%M:%S')"
        
        echo -e "\n## 🚪 Puertos y Servicios (Resumen)"
        echo "| Puerto | Estado | Servicio | Versión |"
        echo "| :--- | :--- | :--- | :--- |"
        
        # Extraer la tabla de puertos para el resumen inicial
        grep -E "^[0-9]+/" "$archivo_nmap" | grep -v "SERVICE" | while read -r line; do
            p_data=$(echo "$line" | tr -s ' ')
            p_id=$(echo "$p_data" | cut -d' ' -f1)
            p_stat=$(echo "$p_data" | cut -d' ' -f2)
            p_serv=$(echo "$p_data" | cut -d' ' -f3)
            p_ver=$(echo "$p_data" | cut -d' ' -f4-)
            echo "| $p_id | $p_stat | $p_serv | ${p_ver:-n/a} |"
        done

        echo -e "\n## 📄 Salida Completa de Nmap (Scripts & Vulns)"
        echo "\`\`\`text"
        
        # LÓGICA BRUTA:
        # Sed busca desde la línea que tiene "PORT" hasta el final del archivo.
        # Quitamos las líneas de Nmap done y los tiempos para que sea más limpio.
        sed -n '/PORT/,/Nmap done/p' "$archivo_nmap" | \
        grep -vE "Service detection performed|Nmap done|incorrect results" | \
        sed 's/^[ \t]*//'
        
        echo "\`\`\`"
        
        echo -e "\n---"
        echo "*Reporte generado automáticamente por scan4me*"
    } > "$archivo_md"

    echo -e "${VERDE}✅ Reportes generados correctamente.${RESET}"

    echo -e "${VERDE}✅ Kit de Writeup listo en la carpeta de auditoría en: $(basename "$archivo_md")${RESET}"
}

function despedida() {
    echo -e "\n"
    echo -e "${AZUL}%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%${RESET}"
    echo -e "${BLANCO}     ¡Gracias por usar scan4me! Bye!      ${RESET}"
    echo -e "${AZUL}%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%${RESET}"
    exit 0
}

trap despedida SIGINT
# Comprobación usuario root
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}❌ Este script debe ejecutarse con sudo.${RESET}" 
   echo -e "${AMARILLO}Ejemplo: sudo $0 10.10.10.1${RESET}"
   exit 1
fi

target=$1
subdominio=$2

if [ -z "$target" ]; then
    echo -e "${ROJO}❌ Error: debe introducir la IP o Dominio para empezar${RESET}"
    echo "Uso: ./nmap4me.sh <TARGET>"
    exit 1
fi


# --- LÓGICA DE RE-VERIFICACIÓN ---
check_dependencies() {
    missing_tools=()
    for tool in "${dependencies[@]}"; do
        # Intenta encontrarlo de forma normal, y si no, busca en la ruta de Snap
        if ! command -v "$tool" &> /dev/null && [ ! -f "/snap/bin/$tool" ] && [ ! -f "/var/lib/snapd/snap/bin/$tool" ]; then
            missing_tools+=("$tool")
        fi
    done
}
# --- FLUJO PRINCIPAL DE DEPENDENCIAS ---
check_dependencies

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${ROJO}❌ No se han podido encontrar estas herramientas: ${missing_tools[*]}${RESET}"
    echo -e "${CYAN}¿Qué deseas hacer?${RESET}"
    echo -e "   ${BLANCO}s) Intento de instalación automática (Sudo)${RESET}"
    echo -e "   ${BLANCO}i) Mostrar instrucciones de instalación manual${RESET}"
    echo -e "   ${BLANCO}n) Continuar de todos modos (Puede fallar)${RESET}"
    echo -ne "\n${AMARILLO}Selecciona una opción: ${RESET}"
    read -r confirm

    if [[ "$confirm" == "s" ]]; then
        install_tools "${missing_tools[@]}"
        check_dependencies
       
    elif [[ "$confirm" == "i" ]]; then
        mostrar_instrucciones
        echo -e "\n${CYAN}Una vez instaladas, vuelve a ejecutar el script.${RESET}"
        exit 0
    elif [[ "$confirm" != "n" ]]; then
        echo -e "${ROJO}❌ Abortando.${RESET}"
        exit 1
    fi
fi

# Comprobación de SecLists (wordlist)
# Definimos las rutas posibles
# --- COMPROBACIÓN Y AUTO-INSTALACIÓN DE SECLISTS ---

# Cambiamos la ruta a una que Snap SI pueda leer ($HOME)
# --- COMPROBACIÓN Y AUTO-INSTALACIÓN DE SECLISTS CORREGIDA ---

# 1. Identificar quién es el usuario real (no root) y su HOME
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# 2. Definir rutas posibles (Priorizando el HOME del usuario real)
wordlist_user="$REAL_HOME/seclists/Discovery/Web-Content/common.txt"
wordlist_standard="/usr/share/seclists/Discovery/Web-Content/common.txt"
wordlist_snap="/snap/seclists/current/Discovery/Web-Content/common.txt"

wordlist=""

# 3. Lógica de detección
if [ -f "$wordlist_user" ]; then
    wordlist="$wordlist_user"
elif [ -f "$wordlist_standard" ]; then
    wordlist="$wordlist_standard"
elif [ -f "$wordlist_snap" ]; then
    wordlist="$wordlist_snap"
else
    echo -e "${ROJO}❌ SecLists no detectado.${RESET}"
    echo -ne "${AMARILLO}¿Instalar SecLists vía GIT en $REAL_HOME/seclists? (s/n): ${RESET}"
    read -r install_sl
    
    if [[ "$install_sl" == "s" ]]; then
        echo -e "${AZUL}📥 Instalando git y clonando SecLists...${RESET}"
        
        case "$GESTOR" in
            "apt") sudo apt install -y git ;;
            "dnf") sudo dnf install -y git ;;
            "pacman") sudo pacman -S --noconfirm git ;;
            *) echo "Instala git manualmente"; exit 1 ;;
        esac

        # Clonamos como el usuario normal para que Snap tenga permisos de lectura
        sudo -u "$REAL_USER" git clone --depth 1 https://github.com/danielmiessler/SecLists "$REAL_HOME/seclists"
        
        wordlist="$wordlist_user"

        if [ ! -f "$wordlist" ]; then
            echo -e "${ROJO}❌ Error al clonar. Revisa tu conexión.${RESET}"
            exit 1
        fi
        echo -e "${VERDE}✅ SecLists instalado en $REAL_HOME/seclists${RESET}"
    fi
fi
# Comprobar si el objetivo es alcanzable (IP o Dominio)
echo ""
echo -e "${VERDE}OK ✅ Vamos a empezar ${RESET}"
echo -e "\n${AZUL}🔍 Verificando conexión $target...Esto no debería llevar más de 3 segundos...${RESET}"
echo -e
if ! host "$target" &>/dev/null && ! ping -c 1 -W 1 -q "$target" &>/dev/null; then
    echo -e "${ROJO}⚠️  Atención: No se puede resolver o no hay respuesta de '$target'.${RESET}"
    echo -e -n "\n${AMARILLO}¿Deseas continuar de todos modos? (s/n): ${RESET}"
    read confirm
    [[ "$confirm" != "s" ]] && exit 1
fi
#Creación de carpeta y reporte .txt
folder="Auditoria_${target}_$(date +%d-%m-%Y)"
mkdir -p "$folder"
reporte_txt="$folder/Auditoria_Completa_${target}.txt"

if [ -n "$wordlist" ]; then
    echo -e "\n${VERDE}🔍 Comprobación SecLists instalado:      --- OK ✅${RESET}"
else
    echo -e "\n${ROJO} ⚠️Comprobación SecLists no instalado ❌El fuzzing web no está disponible${RESET}"
fi

echo -e "${VERDE}🔍 Comprobación de programas instalados: --- OK ✅${RESET}"
echo -e "${VERDE}🔍 Conectividad ping con host:           --- OK ✅${RESET}"
echo -e "${VERDE}🔍 Comprobación usuario ROOT:            --- OK ✅${RESET}"
sleep 1
echo
echo -e "${VERDE}✅ Sistema listo! Empezando Auditoria 🚀${RESET}"

sleep 1

# --- NORMALIZACIÓN DE COMANDOS ---
# Esto busca el binario en el PATH o en las rutas estándar de Snap
FEROX_BIN=$(command -v feroxbuster || echo "/snap/bin/feroxbuster")
WPSCAN_BIN=$(command -v wpscan || echo "/usr/local/bin/wpscan")

# Verificamos si realmente existen para evitar errores feos
[[ ! -x "$FEROX_BIN" ]] && FEROX_BIN="feroxbuster" 
[[ ! -x "$WPSCAN_BIN" ]] && WPSCAN_BIN="wpscan"

# BUCLE DEL MENÚ INTERACTIVO
while true; do
    mostrar_logo
    xml_color="${ROJO}"
    [[ "$xml_status" == "ON" ]] && xml_color="${VERDE}"
    echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET}\n"
    
    options=(
        "0. [TOGGLE] Guardar XML: $xml_status"
        "1. Escaneo Automático Nmap            | (-p- -sSCV + Vuln)"
        "2. Otras opciones con Nmap (Submenú)  | nmap"
        "3. Whatweb (Reconocimiento web)       | whatweb"
        "4. Feroxbuster (fuzzing web)          | feroxbuster"    
        "5. Wpscan (reconocimiento wordpress)  | wpscan" 
        "x.           -- SALIR --              | exit"
    )

    selection=$(printf "%s\n" "${options[@]}" | fzf --prompt="🔍 Selecciona el tipo de acción: " --height=15% --layout=reverse --border)
    
# --- DETECTOR DE SELECCIÓN VACÍA (ESC o Enter sin elegir) ---
    if [ -z "$selection" ]; then
        echo -e "\n${ROJO}⚠️  Aviso: No has seleccionado ninguna opción (Selección vacía)\nSi lo que quieres es salir vuelve a pulsar Control+C.${RESET}\n"
        read -n 1 -s -r -p $'\e[1;5;33mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"SALIR"* ]]; then
        despedida
    fi

    if [[ "$selection" == *"TOGGLE"* ]]; then
        if [[ "$xml_status" == "OFF" ]]; then 
            xml_status="ON"; 
        else 
            xml_status="OFF"; 
        fi
        continue
    fi

    # --- OPCIÓN 1: ESCANEO AUTOMÁTICO  ---
    if [[ "$selection" == *"1."* ]] || [[ "$selection" == *"Automático"* ]]; then
        echo -e "\n${AZUL}🚀 Iniciando Escaneo Automático (Fase 1: Descubrimiento de puertos)${RESET}"
        # lógica para extraer puertos
        flags="-sS -p- -n -Pn --open -T4"

      
        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}"
        echo -e "🕒 INICIO AUTO-SCAN: $(date '+%d-%m-%Y %H:%M:%S')"
        echo -e "🚀 COMANDO: nmap $flags $target"
        echo -e "${AZUL}══════════════════════════════════════════════════${RESET}"
        
        open_ports=$(nmap $flags "$target" | grep "/tcp" | cut -d/ -f1 | xargs | tr ' ' ',')
        
        if [ -z "$open_ports" ]; then
            echo -e "${ROJO}❌ No se encontraron puertos abiertos.${RESET}"
        else
            echo -e "\n${VERDE}✅ Puertos encontrados: $open_ports${RESET}"
            echo
            echo -e "${AZUL}🚀 Fase 2: Escaneo de scripts y versiones...${RESET}"
            
            flags="-sSCV -Pn -n -p"

            if [[ "$xml_status" == "ON" ]]; then

            archivo_xml="$folder/nmap_auto_${target}_$(date +%H%M%S)"
        
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" 
            echo -e "🕒 INICIO AUTO-SCAN XML: $(date '+%d-%m-%Y %H:%M:%S')" 
            echo -e "🚀 COMANDO: nmap $flags $target" 
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" 
                
            nmap $flags $open_ports "$target" -oA "$archivo_xml"

            echo
            echo -e "${AZUL}🚀 Fase 3: Escaneo de vulnerabilidades...${RESET}"

            flags="--script vuln -p"

            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" 
            echo -e "🕒 INICIO AUTO-SCAN XML: $(date '+%d-%m-%Y %H:%M:%S')"
            echo -e "🚀 COMANDO: nmap $flags $target"
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" 

            echo -e "\n${CYAN}Este script puede tardar más tiempo, sobre todo si hay muchos puertos abiertos${RESET}\n"
            
            nmap $flags $open_ports "$target" -oA "$archivo_xml"

            procesar_reportes

            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "\n${VERDE}✅ Resultados añadidos procesados en: $archivo_xml${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "\n${VERDE}✅ Escaneo finalizado.${RESET}"
            echo ""
            read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
            continue
            fi
        
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
            echo -e "🕒 INICIO AUTO-SCAN: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
            echo -e "🚀 COMANDO: nmap $flags $open_ports $target" | tee -a "$reporte_txt"
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"
            
            nmap $flags $open_ports "$target" | tee -a "$reporte_txt"
            
            echo
            echo -e "${AZUL}🚀 Fase 3: Escaneo de vulnerabilidades...${RESET}"
            
            flags="--script vuln -p"
            
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
            echo -e "🕒 INICIO AUTO-SCAN: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
            echo -e "🚀 COMANDO: nmap $flags $open_ports $target" | tee -a "$reporte_txt"
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"

            echo -e "${CYAN}Este script puede tardar más tiempo, sobre todo si hay muchos puertos abiertos${RESET}\n"
           
            nmap $flags $open_ports "$target" | tee -a "$reporte_txt"

                
            echo -e "\n${VERDE}📄 Reporte guardado en: $reporte_txt${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "\n${VERDE}✅ Escaneo finalizado.${RESET}"
        fi
        echo
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    # --- OPCIÓN 2: SUBMENÚ NMAP ---
    if [[ "$selection" == *"2. Otras opciones"* ]]; then
        sub_options=(
            "1. Reconocimiento Rápido (OS/Versión) | -sS -O -sV -Pn -T4"
            "2. Escaneo de Puertos Totales (p-)    | -sS -p- -Pn"
            "3. Enumeración de Servicios (sCV)     | -sSCV -Pn -p"
            "4. Escaneo de Vulnerabilidades (Vuln) | --script vuln -Pn -p"
            "5. UDP Discovery (Top 20 Puertos)     | -sU -Pn --top-ports 20 -T4"
            "6. UDP Investigación (Versiones)      | -sU -sV -Pn -p"
            "7. Web Recon (Nmap Scripts)           | NMAP_WEB_RECON"
            "b. << Volver al menú principal"
        )
        
        selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="🛠 Opciones de Nmap: " --height=15% --layout=reverse --border)
        
        [[ "$selection" == *"Volver"* ]] || [ -z "$selection" ] && continue

        # Si es Web Recon (Opcion 7 del submenú)
        if [[ "$selection" == *"Web Recon"* ]]; then
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
            echo -e "🕒 INICIO WEB RECON (Nmap): $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
            echo -e "🚀 OBJETIVO: $target (Puertos por defecto: 80, 443)" | tee -a "$reporte_txt"
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"

            if [[ "$xml_status" == "ON" ]]; then
            archivo_xml="$folder/web_recon_${target}_$(date +%H%M%S).xml"
            nmap -p 80,443 -Pn -sV --script http-enum,http-title,http-methods,http-server-header -oX "$archivo_xml" "$target" | tee -a "$reporte_txt"
            echo -e "\n${VERDE}🌐 XML guardado en: $archivo_xml${RESET}"
            
            else
            nmap -p 80,443 -Pn -sV --script http-enum,http-title,http-methods,http-server-header "$target" | tee -a "$reporte_txt"
            fi

        echo -e "\n${VERDE}✅ Resultados añadidos a: $reporte_txt${RESET}"
        echo -e "\n${AZUL}--------------------------------------------------${RESET}"
        echo -e "\n${VERDE}✅ Escaneo finalizado.${RESET}"
        echo ""
            read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
            continue
        fi

        # Para el resto de opciones del submenú (flags dinámicas)
        flags=$(echo "$selection" | awk -F "|" "{print \$2}" | xargs)

        if [[ "$flags" == *"-p" ]]; then
            echo -e -n "${AMARILLO}🔢 Introduce los puertos (ej: 80,443): ${RESET}"
            read -r ports
            if [ -z "$ports" ]; then
            echo -e "${ROJO}❌ Error: Para esta opción debes indicar puertos.${RESET}"
            sleep 1
            continue
            fi
            flags="${flags} ${ports}"
        fi

        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
        echo -e "🕒 INICIO NMAP: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
        echo -e "🚀 COMANDO: nmap $flags $target" | tee -a "$reporte_txt"
        echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"
       
        # Opción XML basada en el interruptor de la Opción 0
        if [[ "$xml_status" == "ON" ]]; then
        archivo_xml="$folder/nmap_${target}_$(date +%H%M%S).xml"
        nmap $flags -oX "$archivo_xml" "$target" | tee -a "$reporte_txt"
        echo -e "\n${VERDE}🌐 XML guardado en: $archivo_xml${RESET}"
        else
        nmap $flags "$target" | tee -a "$reporte_txt"
        fi
    
        echo -e "\n${VERDE}📄 Reporte guardado en: $reporte_txt${RESET}"
        echo -e "\n${AZUL}--------------------------------------------------${RESET}"
        echo -e "${VERDE}✅ Escaneo finalizado.${RESET}"
        
        echo
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    # --- OPCIONES (WHATWEB, FEROX, WPSCAN) ---
    if [[ "$selection" == *"Whatweb"* ]]; then
        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
        echo -e "🕒 INICIO WHATWEB: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
        echo -e "🚀 COMANDO: ${VERDE}whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 $target${RESET}" | tee -a "$reporte_txt"
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"

        whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 "$target" | tee -a "$reporte_txt"
        
        echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"4. Feroxbuster"* ]]; then
        
        if [ -z "$wordlist" ]; then
        echo -e "${ROJO}❌ Error: No puedes usar Feroxbuster sin el diccionario SecLists.${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
        fi
        url="$target"
        if [[ ! "$url" =~ ^https?:// ]]; then
            url="http://$url"
        fi

        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
        echo -e "🕒 INICIO feroxbuster: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
        echo -e "🚀 COMANDO: ${VERDE}feroxbuster --url $url --wordlist $wordlist --extensions bak,zip,txt,sql,old,php.bak --no-recursion --filter-size 0 --threads 50 --timeout 5${RESET}" | tee -a "$reporte_txt"
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"
       
        
        $FEROX_BIN --url $url --wordlist "$wordlist" --extensions bak,zip,txt,sql,old,php.bak --no-recursion --filter-size 0 --threads 50 --timeout 5 | tee -a "$reporte_txt"
        
        echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"Wpscan"* ]]; then
        url="$target"
        if [[ ! "$url" =~ ^https?:// ]]; then
            url="http://$url"
        fi
        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | tee -a "$reporte_txt"
        echo -e "🕒 INICIO wpscan: $(date '+%d-%m-%Y %H:%M:%S')" | tee -a "$reporte_txt"
        echo -e "🚀 COMANDO: ${VERDE}wpscan --url $url$subdominio -e u,ap --detection-mode aggressive --force${RESET}" | tee -a "$reporte_txt"
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | tee -a "$reporte_txt"
        #Aviso para opción subdominio wordpress
        echo -e "${ROJO}---------------  *ATENCIÓN*  ---------------${RESET}\nSi el wordpress está alojado en un subdominio, se debe salir y volver a ejecutar el script introduciendo la ip con un espacio /subdominio.\n\n${MAGENTA}------> Ejemplo: 172.17.0.2 /wordpress${RESET}"

        
        $WPSCAN_BIN --url $url$subdominio -e u,ap --detection-mode aggressive --force | tee -a "$reporte_txt"
        
        echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""   
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi
done