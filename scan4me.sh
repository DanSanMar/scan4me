#!/usr/bin/env bash

export TERM=xterm-256color

# Colores a \033 para mayor compatibilidad
BLANCO="\033[1;37m"
AZUL="\033[1;36m"
AMARILLO="\033[1;33m"
ROJO="\033[1;31m"
VERDE="\033[1;32m"
RESET="\033[0m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"


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
dependencies=(fzf nmap whatweb feroxbuster wpscan xsltproc host arp-scan smbclient nbtscan enum4linux gobuster)


# --- MAPEO DE NOMBRES DE PAQUETES  ---
get_package_name() {
    local tool=$1
    case "$tool" in
        "xsltproc") echo "xsltproc" ;;
        "host") [[ "$GESTOR" == "apt" ]] && echo "dnsutils" || echo "bind-utils" ;;
        "feroxbuster") echo "SNAP_REQUIRED" ;;
        "wpscan") echo "GEM_REQUIRED" ;; # Cambiamos Snap por Ruby Gems
        "arp-scan") echo "arp-scan" ;;
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
            "fzf"|"nmap"|"whatweb"|"xsltproc"|"host"|"arp-scan")
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

function buscar_subdominios() {
    # Verificar si el target parece un dominio o host válido, no una IP pura
    if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${ROJO}❌ Error: La búsqueda de subdominios requiere un dominio (ej: target.local), no una IP (${target}).${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver... \e[0m'
        return
    fi

    # Comprobar si tenemos SecLists
    if [ -z "$wordlist" ]; then
        echo -e "${ROJO}❌ Error: Se requiere SecLists para esta función.${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver... \e[0m'
        return
    fi

    # Intentar localizar un diccionario de subdominios en SecLists, si no usa el común
    local sub_wordlist="${wordlist%/*/*}/Discovery/DNS/subdomains-top1million-5000.txt"
    if [ ! -f "$sub_wordlist" ]; then
        sub_wordlist="$wordlist" # Fallback al common.txt de web-content si no encuentra el de DNS
    fi

    if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando GoBuster DNS...${RESET}"; fi
    echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
    echo -e "🕒 INICIO SUBDOMINIOS (GoBuster): $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
    echo -e "🚀 COMANDO: gobuster dns -d $target -w $sub_wordlist -t 50 --show-ips" | output_txt
    echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt

    gobuster dns -d "$target" -w "$sub_wordlist" -t 50 --show-ips | output_txt

    [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}✅ Resultados guardados en: $reporte_txt${RESET}"
    echo ""
    read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
}

function procesar_reportes() {
    # Aseguramos que la carpeta existe y no está vacía
    local backup_folder="Auditoria_${target}_$(date +%d-%m-%Y)"
    local current_folder="${folder:-$backup_folder}"
    
    local xml_versiones=$(ls -t "$current_folder"/nmap_auto_${target}_*_fase2.xml 2>/dev/null | head -n 1)
    local xml_vulns=$(ls -t "$current_folder"/nmap_auto_${target}_*_fase3.xml 2>/dev/null | head -n 1)
    
    if [ -z "$xml_versiones" ]; then
        echo -e "${ROJO}⚠️ No se encontró el reporte XML base para procesar la automatización.${RESET}"
        return
    fi

    local timestamp=$(date +%H%M%S)
    local archivo_html="$current_folder/Writeup_${target}_${timestamp}.html"
    local archivo_md="$current_folder/Writeup_${target}_${timestamp}.md"
    local archivo_ia="$current_folder/ia_prompt_${target}.txt"

    # 1. Generar HTML si xsltproc existe
    if command -v xsltproc &> /dev/null; then
        xsltproc "$xml_versiones" -o "$archivo_html" 2>/dev/null
        echo -e "${VERDE}✅ Kit de Writeup HTML generado en: ${BLANCO}$(basename "$archivo_html")${RESET}"
    fi

    local nmap_file="${xml_versiones%.xml}.nmap"
    local vuln_file="${xml_vulns%.xml}.nmap"

    # 2. Generar Markdown estructurado (Tu reporte de cara al CTF)
    {
        echo "# 🎯 CTF Writeup / Auto-Report: $target"
        echo "📅 **Fecha de Auditoría:** $(date '+%d-%m-%Y %H:%M:%S')"
        echo "💻 **Objetivo (Target IP):** \`$target\`"
        echo ""
        echo "## 📝 1. Resumen Ejecutivo"
        echo "Informe automático de vulnerabilidades y reconocimiento generado para entornos CTF."
        echo ""
        echo "## 🚪 2. Puertos y Servicios Detectados"
        echo "| Puerto | Estado | Servicio | Versión |"
        echo "| :---: | :---: | :--- | :--- |"
        
        if [ -f "$nmap_file" ]; then
            grep -E "^[0-9]+/" "$nmap_file" | grep -v "SERVICE" | while read -r line; do
                p_data=$(echo "$line" | tr -s ' ')
                p_id=$(echo "$p_data" | cut -d' ' -f1)
                p_stat=$(echo "$p_data" | cut -d' ' -f2)
                p_serv=$(echo "$p_data" | cut -d' ' -f3)
                p_ver=$(echo "$p_data" | cut -d' ' -f4-)
                echo "| **$p_id** | \`$p_stat\` | $p_serv | ${p_ver:-n/a} |"
            done
        else
            echo "| - | No se pudo procesar la tabla de puertos directos. | - | - |"
        fi

        echo ""
        echo "## 🔍 3. Análisis de Versiones Detallado"
        echo "\`\`\`text"
        [ -f "$nmap_file" ] && sed -n '/PORT/,/Nmap done/p' "$nmap_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//'
        echo "\`\`\`"

        if [ -f "$vuln_file" ]; then
            echo ""
            echo "## ⚡ 4. Auditoría de Vulnerabilidades (Scripts Nmap)"
            echo "\`\`\`text"
            sed -n '/PORT/,/Nmap done/p' "$vuln_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//'
            echo "\`\`\`"
        fi
    } > "$archivo_md"

    echo -e "${VERDE}✅ Reporte Markdown estructurado listo en: ${BLANCO}$(basename "$archivo_md")${RESET}"

    # =========================================================================
    # 3. NUEVO: ARCHIVO DE TEXTO ULTRA-OPTIMIZADO PARA IA 
    # =========================================================================
    # Extraemos la lista limpia de puertos directamente desde el archivo final
    local ports_list=""
    if [ -f "$nmap_file" ]; then
        ports_list=$(grep -E "^[0-9]+/" "$nmap_file" | cut -d/ -f1 | xargs | tr ' ' ',')
    fi

    {
        echo "ACTÚA COMO UN TUTOR EXPERTO EN CIBERSEGURIDAD Y METODOLOGÍAS CTF."
        echo "Tu objetivo es guiar de forma educativa e instructiva en el análisis de vulnerabilidades para entornos de laboratorio controlado."
        echo "Analiza el siguiente output técnico recopilado sobre el objetivo: $target"
        echo "Por favor, estructura tu respuesta detallando los siguientes puntos:"
        echo "1. **Análisis de Superficie de Ataque:** Identifica servicios detectados, versiones obsoletas y posibles malas configuraciones."
        echo "2. **Investigación Teórica (CVE):** Indica si existen vulnerabilidades conocidas asociadas a esas versiones y explica brevemente en qué consiste el fallo de seguridad."
        echo "3. **Vectores de Entrada Sugeridos:** Explica conceptualmente cómo se podría interactuar con el servicio para validar la vulnerabilidad."
        echo "4. **Metodología de Explotación Educativa:** Describe la lógica o los pasos conceptuales detallados (y las herramientas estándar de la industria como curl, nmap, netcat, etc.) necesarios para comprobar el vector de ataque en un entorno controlado."
        echo "5. **Remediación y Buenas Prácticas:** Explica brevemente cómo se corregiría este fallo en un entorno de producción real."
        echo "Mantén un tono académico, técnico y didáctico. Responde en español."
        echo "--- START TARGET DATA ---"
        echo "TARGET_IP: $target"
        echo "PORTS_OPEN: ${ports_list:-Desconocidos}"
        echo ""
        echo "[VERSIONS_AND_SERVICES]"
        if [ -f "$nmap_file" ]; then
            sed -n '/PORT/,/Nmap done/p' "$nmap_file" | grep -vE "Service detection performed|Nmap done|SF:" | sed 's/^[ \t]*//' | grep -v "^$"
        fi
        echo ""
        echo "[VULNERABILITY_SCRIPTS]"
        if [ -f "$vuln_file" ]; then
            sed -n '/PORT/,/Nmap done/p' "$vuln_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//' | grep -v "^$"
        fi
        echo "--- END TARGET DATA ---"
    } > "$archivo_ia"

    echo -e "${VERDE}🤖 Archivo optimizado para IA generado en: ${BLANCO}$(basename "$archivo_ia")${RESET}\n"
}

# --- VARIABLE DE ESTADO XML ---
xml_status="OFF"
txt_status="OFF"

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
    echo -e "${BLANCO}              ░▒▓ ALL  4  M E ▓▒░ --[ V 5.7 ]--"
    echo -e "${AZUL}--[ Escaneo Interactivo de Red con multiherramientas ]--${RESET}"
    echo -e "${BLANCO}--===============================================================${RESET}"
    echo -e "${BLANCO}--[ Auto-install + Auto-scan + Recon Red + Gobuster + Nmap +  ]--${RESET}"
    echo -e "${BLANCO}--[ Feroxbuster + SectList + Wpscan + Nmap Auto + scan4windows]--${RESET}"
    echo ""
}

function output_txt() {
    if [[ "$txt_status" == "ON" ]]; then
        tee -a "$reporte_txt"
    else
        cat
    fi
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

# --- LÓGICA DE RE-VERIFICACIÓN (MOVIDA AQUÍ ARRIBA) ---
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

# --- MODO AUTODETECCIÓN DE RED LOCAL SI NO HAY PARÁMETRO ---
if [ -z "$target" ]; then
    echo -e "${AMARILLO}⚠️  No has especificado ningún objetivo (IP/Dominio).${RESET}"
    echo -e "${AZUL}🔍 Detectando subredes y escaneando la red...${RESET}\n"
    sleep 1

    # Archivos temporales para aislar todo el proceso
    tmp_raw="/tmp/scan4me_raw.txt"
    tmp_clean="/tmp/scan4me_clean.txt"
    > "$tmp_raw"

    # 1. Fase de descubrimiento ARP en todas las interfaces posibles
    arp-scan --localnet --ignoredups 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> "$tmp_raw"

    # 2. Fase de descubrimiento Nmap iterando por TODAS las subredes válidas
    # Extraemos todos los rangos IP asignados a la máquina (excluyendo la interfaz loopback)
    subnets=$(ip -o -4 addr show | awk '{print $4}' | grep -v '127.0.0.1')

    for subnet in $subnets; do
        # Evitamos rangos de host único /32 para no perder tiempo
        [[ "$subnet" == */32 ]] && continue
        
        echo -e "${CYAN}📡 Escaneando subred: $subnet...${RESET}"
        
        # PARAMETROS DE VELOCIDAD AGRESIVOS:
        # --min-rate 5000: Envía mínimo 5000 paquetes por segundo (ideal para redes internas/virtuales)
        # --max-rtt-timeout 20ms: Si un host local no responde en 20ms, pasa al siguiente (el script original esperaba hasta 1 segundo por IP)
        # --host-timeout 1s: No pierde más de un segundo por host problemático
        nmap -sn -PS22,80,443,445 -PE --min-rate 5000 --max-rtt-timeout 20ms --host-timeout 1s "$subnet" 2>/dev/null | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' >> "$tmp_raw"
    done

    # 3. Limpiamos las IPs, eliminamos duplicados y la IP de nuestra propia máquina
    my_ips=$(hostname -I)
    sort -u "$tmp_raw" | grep -E '^[0-9]' | while read -r ip; do
        # Si la IP encontrada coincide con una de nuestras IPs locales, la descartamos
        if [[ ! " $my_ips " =~ " $ip " ]]; then
            echo "$ip" >> "$tmp_clean"
        fi
    done
    rm -f "$tmp_raw"

    # 4. Pasar el archivo final a FZF
    if [ ! -s "$tmp_clean" ]; then
        echo -e "${ROJO}❌ No se detectó ningún host activo en las subredes automáticamente.${RESET}"
        echo -ne "${AMARILLO}Introduce la IP manualmente para empezar: ${RESET}"
        read -r target
        if [ -z "$target" ]; then echo -e "${ROJO}❌ Abortando.${RESET}"; rm -f "$tmp_clean"; exit 1; fi
    else
        echo -e "\n${AZUL}Selecciona un objetivo de la lista con FZF:${RESET}"
        target=$(cat "$tmp_clean" | fzf --prompt="🎯 Selecciona la IP víctima: " --height=40% --layout=reverse --border)
    fi

    rm -f "$tmp_clean"

    # 5. Validación final del objetivo seleccionado
    if [ -z "$target" ]; then
        echo -e "${ROJO}❌ Selección inválida o cancelada. Saliendo...${RESET}"
        exit 1
    fi
    
    echo -e "\n${VERDE}🎯 Objetivo seleccionado con éxito: $target${RESET}"
    sleep 1
fi

# --- COMPROBACIÓN Y AUTO-INSTALACIÓN DE SECLISTS ---

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
    read -r confirm
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
FEROX_BIN=$(command -v feroxbuster || echo "/snap/bin/feroxbuster")
WPSCAN_BIN=$(command -v wpscan || echo "/usr/local/bin/wpscan")

[[ ! -x "$FEROX_BIN" ]] && FEROX_BIN="feroxbuster" 
[[ ! -x "$WPSCAN_BIN" ]] && WPSCAN_BIN="wpscan"

# BUCLE DEL MENÚ INTERACTIVO
while true; do
    mostrar_logo
    xml_color="${ROJO}"
    [[ "$xml_status" == "ON" ]] && xml_color="${VERDE}"
    
    txt_color="${ROJO}"
    [[ "$txt_status" == "ON" ]] && txt_color="${VERDE}"
    
    echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
    
    options=(
        "x   [CAMBIAR MODO GUARDADO TXT]        | Estado actual: $txt_status"
        "x   [CAMBIAR MODO CONFIG XML]          | Estado actual: $xml_status"
        "1.  Escaneo Automático Nmap (CTF)      | (-p- -sSCV + Vuln)"
        "2.  Otras opciones con Nmap (Submenú)  | nmap"
        "3.  Whatweb (Reconocimiento web)       | whatweb"
        "4.  Gobuster (Fuzzing Subdominios)     | subdomains"
        "5.  Feroxbuster (fuzzing web)          | feroxbuster"    
        "6.  Wpscan (reconocimiento wordpress)  | wpscan" 
        "7.  Otras opciones (solo windows)      | windows" 
        "x.            -- SALIR --              | exit"
    )

    selection=$(printf "%s\n" "${options[@]}" | fzf --prompt="🔍 Selecciona el tipo de acción: " --height=18% --layout=reverse --border)
    
    if [ -z "$selection" ]; then
        echo -e "\n${ROJO}⚠️  Aviso: No has seleccionado ninguna opción (Selección vacía)\nSi lo que quieres es salir vuelve a pulsar Control+C.${RESET}\n"
        read -n 1 -s -r -p $'\e[1;5;33mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"SALIR"* ]]; then
        despedida
    fi

    if [[ "$selection" == *"[CAMBIAR MODO CONFIG XML]"* ]]; then
        if [[ "$xml_status" == "OFF" ]]; then xml_status="ON"; else xml_status="OFF"; fi
        continue
    fi
    
    if [[ "$selection" == *"[CAMBIAR MODO GUARDADO TXT]"* ]]; then
        if [[ "$txt_status" == "OFF" ]]; then txt_status="ON"; else txt_status="OFF"; fi
        continue
    fi

    # --- OPCIÓN 1: ESCANEO AUTOMÁTICO ---
    if [[ "$selection" == *"1."* ]] || [[ "$selection" == *"Automático"* ]]; then
        echo -e "\n${AZUL}🚀 Iniciando Escaneo Automático (Fase 1: Descubrimiento de puertos)${RESET}"
        flags="-sS -p- -n -Pn --open --min-rate 5000"

        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO AUTO-SCAN: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        echo -e "🚀 COMANDO: nmap $flags $target" | output_txt
        echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        
        # Guardamos el descubrimiento y lo enviamos al log TXT si procede
        nmap $flags "$target" | tee /tmp/scan4me_fase1.txt | output_txt
        open_ports=$(grep "/tcp" /tmp/scan4me_fase1.txt | cut -d/ -f1 | xargs | tr ' ' ',')
        rm -f /tmp/scan4me_fase1.txt
        
        if [ -z "$open_ports" ]; then
            echo -e "\n${ROJO}❌ No se encontraron puertos abiertos con el escaneo rápido.${RESET}" | output_txt
            echo -e "${CYAN}⚠️ Procediendo a un segundo análisis más sigiloso para evadir firewalls...${RESET}" | output_txt
            
            flags_sigilo="-sF --top-ports 1000 -Pn -n --open -T3 --data-length 25 --spoof-mac cisco"
            
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO ESCANEO SIGILOSO: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: nmap $flags_sigilo $target" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            
            nmap $flags_sigilo "$target" | tee /tmp/scan4me_sigilo.txt | output_txt
            open_ports=$(grep "/tcp" /tmp/scan4me_sigilo.txt | cut -d/ -f1 | xargs | tr ' ' ',')
            rm -f /tmp/scan4me_sigilo.txt
            
            if [ -z "$open_ports" ]; then
                echo -e "\n${ROJO}❌ Tampoco se detectaron puertos con el escaneo sigiloso. El host podría estar caído o protegido.${RESET}" | output_txt
                echo ""
                read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
                continue
            else
                echo -e "\n${VERDE}✅ ¡Éxito! Puertos detectados mediante sigilo: $open_ports${RESET}" | output_txt
            fi
        else
            echo -e "\n${VERDE}✅ Puertos detectados correctamente: $open_ports${RESET}" | output_txt
        fi

        # --- FLUJO DE EXPLOTACIÓN (Fase 2 y 3) ---
        echo
        echo -e "${AZUL}🚀 Fase 2: Escaneo de scripts y versiones...${RESET}"

        current_time=$(date +%H%M%S)
        archivo_fase2="$folder/nmap_auto_${target}_${current_time}_fase2"
        archivo_fase3="$folder/nmap_auto_${target}_${current_time}_fase3"
        flags_fase2="-sSCV -Pn -n -v -p"
        flags_fase3="--script vuln -v -p"

        if [[ "$xml_status" == "ON" ]]; then
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO AUTO-SCAN XML (Versiones): $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: nmap $flags_fase2 $open_ports $target -oA $archivo_fase2" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
                
            # Ejecución con salida XML/Nmap y canalizada también hacia tu log TXT global
            nmap $flags_fase2 $open_ports "$target" -oA "$archivo_fase2" | output_txt

            echo
            echo -e "${AZUL}🚀 Fase 3: Escaneo de vulnerabilidades...${RESET}"
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO AUTO-SCAN XML (Vuln): $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: nmap $flags_fase3 $open_ports $target -oA $archivo_fase3" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "\n${CYAN}Este script puede tardar más tiempo, sobre todo si hay muchos puertos abiertos${RESET}\n"
            
            nmap $flags_fase3 $open_ports "$target" -oA "$archivo_fase3" | output_txt

            # Invocamos tu procesador automático de Writeups
            procesar_reportes

            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "\n${VERDE}✅ Reportes completos XML, HTML y Markdown procesados en: $folder${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "${AMARILLO}🧹 Si quieres coservar todos los archivos raw pulsa Control+C para salir directamente${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            read -n 1 -s -r -p $'\e[1;5;32mEn caso contrario, pulsa cualquier tecla realizar una limpieza y dejar solo los reportes finales...\e[0m'

            # === 🧹 LIMPIEZA DE RUIDO INNECESARIO ===
            # Borramos los archivos temporales de Nmap (.xml, .nmap, .gnmap)
            # de las fases de esta sesión para dejar la carpeta impecable.
            rm -f "${archivo_fase2}.xml" "${archivo_fase2}.nmap" "${archivo_fase2}.gnmap"
            rm -f "${archivo_fase3}.xml" "${archivo_fase3}.nmap" "${archivo_fase3}.gnmap"

            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "\n${VERDE}✅ Reportes limpios y estructurados listos en: $folder${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
        else
            # Si XML está OFF, hacemos el flujo equivalente en texto plano para pantalla y log TXT
            echo -e "\n${AZUL}🕒 INICIO AUTO-SCAN TEXTO (Versiones)...${RESET}" | output_txt
            nmap $flags_fase2 $open_ports "$target" | output_txt

            echo -e "\n${AZUL}🚀 Fase 3: Escaneo de vulnerabilidades (Texto)...${RESET}" | output_txt
            nmap $flags_fase3 $open_ports "$target" | output_txt
        fi

        echo -e "\n${VERDE}✅ Escaneo finalizado.${RESET}"
        [[ "$txt_status" == "ON" ]] && echo -e "${VERDE}📄 Log unificado guardado en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi 

    # --- OPCIÓN 2: SUBMENÚ NMAP ---
    if [[ "$selection" == *"Nmap (Submenú)"* ]]; then
        sub_options=(
            "1.  [TCP] Reconocimiento Rápido OS           | -sS -O -Pn -n -vvv -T4"
            "2.  [TCP] Escaneo de Puertos Totales (p-)    | -sS -p- -Pn -n --min-rate 5000"
            "3.  [TCP] Escaneo Agresivo Completo (-A)     | -A -Pn -v"
            "4.  [TCP] Enumeración de Servicios (sCV)     | -sS -sCV -Pn -v -p"
            "5.  [VULN] Escaneo de Vulnerabilidades       | --script vuln -v -Pn -p"
            "6.  [EVASIÓN] Mapeo de Firewall (ACK Scan)   | -sA -Pn -vv -T4"
            "7.  [EVASIÓN] Bypass (Señuelos + DNS Src)    | -sS -Pn -vv -f -D RND:5 -g 53 --data-length 25 --max-rate 100"
            "8.  [UDP] Discovery Rápido (Top 20 Puertos)  | -sU -Pn --top-ports 20 -T4"
            "9.  [UDP] Investigación Profunda (Versiones) | -sU -sV -Pn -p"
            "10. [WEB] Recon Básica (Enum, Robots, Title) | --script http-enum,http-robots.txt,http-title -p 80,443 -Pn"
            "11. [WEB] Recon Completo (Vulns Web)         | --script http-vuln-* -p 80,443 -v -Pn"
            "b. << Volver al menú principal"
        )
        
        # Usamos una variable separada (sub_selection) para no pisar la lógica global
        sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="🛠 Opciones de Nmap: " --height=25% --layout=reverse --border)
        
        [[ "$sub_selection" == *"Volver"* || -z "$sub_selection" ]] && continue

        flags=$(echo "$sub_selection" | awk -F "|" "{print \$2}" | xargs)

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

        if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando Nmap...${RESET}"; fi
        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        if [[ "$sub_selection" == *"Web Recon"* ]]; then
            echo -e "🕒 INICIO WEB RECON (Nmap): $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        else
            echo -e "🕒 INICIO NMAP: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        fi
        echo -e "🚀 COMANDO: nmap $flags $target" | output_txt
        echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | output_txt
       
        if [[ "$xml_status" == "ON" ]]; then
            if [[ "$sub_selection" == *"Web Recon"* ]]; then prefix="web_recon"; else prefix="nmap"; fi
            
            archivo_xml="$folder/${prefix}_${target}_$(date +%H%M%S).xml"
            nmap $flags -oX "$archivo_xml" "$target" | output_txt
            echo -e "\n${VERDE}🌐 XML guardado en: $archivo_xml${RESET}"
        else
            nmap $flags "$target" | output_txt
        fi
    
        [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}📄 Reporte guardado en: $reporte_txt${RESET}"
        echo -e "\n${AZUL}--------------------------------------------------${RESET}"
        echo -e "${VERDE}✅ Escaneo finalizado.${RESET}"
        
        echo
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    # --- OPCIONES (WHATWEB, FEROX, WPSCAN) ---
    if [[ "$selection" == *"Whatweb"* ]]; then
        if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando whatweb...${RESET}"; fi
        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO WHATWEB: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        echo -e "🚀 COMANDO: whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 $target" | output_txt
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt

        whatweb -a 1 -t 1 -v --no-errors --open-timeout=5 --read-timeout=5 "$target" | output_txt
        
        [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"Feroxbuster"* ]]; then
        if [ -z "$wordlist" ]; then
        echo -e "${ROJO}❌ Error: No puedes usar Feroxbuster sin el diccionario SecLists.${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
        fi
        url="$target"
        if [[ ! "$url" =~ ^https?:// ]]; then
            url="http://$url"
        fi

        if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando feroxbuster...${RESET}"; fi
        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO feroxbuster: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        echo -e "🚀 COMANDO: feroxbuster --url $url --wordlist $wordlist --extensions bak,zip,txt,sql,old,php.bak --no-recursion --filter-size 0 --threads 50 --timeout 5" | output_txt
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt
       
        $FEROX_BIN --url $url --wordlist "$wordlist" --extensions bak,zip,txt,sql,old,php.bak --no-recursion --filter-size 0 --threads 50 --timeout 5 | output_txt
        
        [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"Wpscan"* ]]; then
        url="$target"
        if [[ ! "$url" =~ ^https?:// ]]; then
            url="http://$url"
        fi
        
        if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando wpscan...${RESET}"; fi
        echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO wpscan: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        echo -e "🚀 COMANDO: wpscan --url $url$subdominio -e u,ap --detection-mode aggressive --force" | output_txt
        echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt
        echo -e "${ROJO}---------------  *ATENCIÓN* ---------------${RESET}\nSi el wordpress está alojado en un subdominio, se debe salir y volver a ejecutar el script introduciendo la ip con un espacio /subdominio.\n\n${MAGENTA}------> Ejemplo: 172.17.0.2 /wordpress${RESET}"

        $WPSCAN_BIN --url $url$subdominio -e u,ap --detection-mode aggressive --force | output_txt
        
        [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""   
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi

    if [[ "$selection" == *"subdomains"* ]] || [[ "$selection" == *"Gobuster"* ]]; then
        buscar_subdominios
        continue
    fi

    # --- OPCIÓN 6: SUBMENÚ WINDOWS ---
    if [[ "$selection" == *"windows"* ]]; then
        sub_options=(
            "1.  [Nmap] Enumeración SMB Básica (Carpetas/OS)   | nmap --script smb-os-discovery,smb-enum-shares -p 139,445 -Pn"
            "2.  [Nmap] Enumeración NetBIOS (UDP 137)          | nmap -sU -p 137 --script nbstat -Pn"
            "3.  [Nmap] Escaneo de Vulnerabilidades SMB        | nmap --script smb-vuln* -p 139,445 -Pn"
            "4.  [SMBClient] Listar recursos (Sesión Nula)     | smbclient -L //$target -N"
            "5.  [Nbtscan] Escaneo NetBIOS rápido              | nbtscan -r $target"
            "6.  [Enum4Linux] Enumeración completa             | enum4linux -a $target"
            "x.  << Volver al menú principal                   | back"
        )
        
        sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="🪟 Opciones específicas para Windows: " --height=25% --layout=reverse --border)
        
        [[ "$sub_selection" == *"Volver"* || -z "$sub_selection" ]] && continue

        # Extraemos el comando (lo que está a la derecha del '|')
        cmd_raw=$(echo "$sub_selection" | awk -F "|" '{print $2}' | xargs)

        # Separamos la lógica: Nmap soporta XML, las demás herramientas NO.
        if [[ "$cmd_raw" == nmap* ]]; then
            # Es un comando Nmap
            flags=${cmd_raw#nmap } # Quitamos 'nmap ' del string para quedarnos solo con las flags
            
            if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando Nmap (Recon Windows)...${RESET}"; fi
            
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO WINDOWS RECON: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: nmap $flags $target" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | output_txt
           
            if [[ "$xml_status" == "ON" ]]; then
                archivo_xml="$folder/windows_recon_${target}_$(date +%H%M%S).xml"
                nmap $flags -oX "$archivo_xml" "$target" | output_txt
                echo -e "\n${VERDE}🌐 XML guardado en: $archivo_xml${RESET}"
            else
                nmap $flags "$target" | output_txt
            fi

        else
            # Es otra herramienta (smbclient, nbtscan, enum4linux)
            if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando herramienta externa...${RESET}"; fi
            
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO WINDOWS RECON: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: $cmd_raw" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}\n" | output_txt

            # Usamos eval para que bash interprete la variable $target dentro del string cmd_raw
            eval "$cmd_raw" 2>&1 | output_txt

            if [[ "$xml_status" == "ON" ]]; then
                echo -e "\n${AMARILLO}⚠️ Nota: El formato XML automático de este script solo soporta comandos Nmap. El resultado se ha mostrado en pantalla y guardado en TXT (si está activado).${RESET}"
            fi
        fi

        [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}📄 Reporte guardado en: $reporte_txt${RESET}"
        echo -e "\n${AZUL}--------------------------------------------------${RESET}"
        echo -e "${VERDE}✅ Escaneo de Windows finalizado.${RESET}"
        
        echo
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi
done
