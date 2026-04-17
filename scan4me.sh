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
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

GESTOR=$(detectar_gestor)

# --- DEFINICIÓN DE DEPENDENCIAS ---
dependencies=(fzf nmap whatweb feroxbuster wpscan xsltproc host)

# --- LÓGICA DE INSTALACIÓN ---
install_tools() {
    local tools_to_install=("$@")
    
    if [ ${#tools_to_install[@]} -eq 0 ]; then
        echo -e "${VERDE}✅ Todas las dependencias están satisfechas.${RESET}"
        return 0
    fi

    echo -e "${AMARILLO}🔧 Se detectaron herramientas faltantes: ${tools_to_install[*]}${RESET}"
    
    # Actualizar repositorios
    if [[ "$GESTOR" == "apt" ]]; then
        echo -e "${AZUL}🔄 Actualizando repositorios (apt)...${RESET}"
        sudo apt update
    elif [[ "$GESTOR" == "dnf" ]]; then
        echo -e "${AZUL}🔄 Actualizando repositorios (dnf)...${RESET}"
        sudo dnf makecache
    elif [[ "$GESTOR" == "zypper" ]]; then
        echo -e "${AZUL}🔄 Actualizando repositorios (zypper)...${RESET}"
        sudo zypper refresh
    elif [[ "$GESTOR" == "pacman" ]]; then
        echo -e "${AZUL}🔄 Actualizando repositorios (pacman)...${RESET}"
        sudo pacman -Sy
    fi

    for tool in "${tools_to_install[@]}"; do
        pkg=$(get_package_name "$tool")
        echo -e "${AZUL}📦 Instalando: $tool (paquete: $pkg) ...${RESET}"
        
        local success=false
        
        case "$GESTOR" in
            "apt")
                sudo apt install -y "$pkg" && success=true
                ;;
            "dnf")
                sudo dnf install -y "$pkg" && success=true
                ;;
            "pacman")
                sudo pacman -S --noconfirm "$pkg" && success=true
                ;;
            "zypper")
                sudo zypper install -y "$pkg" && success=true
                ;;
            *)
                # Fallback a Snap
                if command -v snap &> /dev/null; then
                    echo -e "${AMARILLO}⚠️ Gestor no detectado, intentando vía Snap...${RESET}"
                    local snap_flags=""
                    [[ "$tool" == "fzf" || "$tool" == "feroxbuster" ]] && snap_flags="--classic"
                    sudo snap install "$pkg" $snap_flags && success=true
                else
                    echo -e "${ROJO}❌ Error: No se pudo instalar $tool automáticamente.${RESET}"
                fi
                ;;
        esac

        if [ "$success" = false ]; then
            echo -e "${ROJO}⚠️ Falló la instalación de $tool.${RESET}"
        fi
    done
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
    echo -e "${BLANCO}--[ Versión: 4 Nmap + Feroxbuster + SectList + Wpscan + Nmap Auto + Auto-install]--${RESET}"
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

# --- MAPEO DE NOMBRES DE PAQUETES (CORREGIDO) ---
get_package_name() {
    local tool=$1
    case "$tool" in
        "xsltproc")
            if [[ "$GESTOR" == "apt" ]]; then echo "libxml2-utils"
            elif [[ "$GESTOR" == "dnf" || "$GESTOR" == "zypper" ]]; then echo "libxml2-utils"
            elif [[ "$GESTOR" == "pacman" ]]; then echo "libxml2"
            else echo "xsltproc"
            fi
            ;;
        "host")
            if [[ "$GESTOR" == "apt" ]]; then echo "dnsutils"
            elif [[ "$GESTOR" == "dnf" || "$GESTOR" == "zypper" ]]; then echo "bind-utils"
            elif [[ "$GESTOR" == "pacman" ]]; then echo "bind"
            else echo "bind-utils"
            fi
            ;;
        "feroxbuster")
            echo "feroxbuster"
            ;;
        "fzf")
            echo "fzf"
            ;;
        *)
            echo "$tool"
            ;;
    esac
}

# --- LÓGICA DE RE-VERIFICACIÓN ROBUSTA ---
check_dependencies() {
    missing_tools=()
    for tool in "${dependencies[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
}

# --- FLUJO PRINCIPAL INTEGRADO ---
check_dependencies

if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${ROJO}❌ Faltan herramientas: ${missing_tools[*]}${RESET}"
    echo -e "${AMARILLO}¿Deseas intentar instalarlas automáticamente? (s/n): ${RESET}"
    read confirm

    if [[ "$confirm" == "s" ]]; then
        echo -e "${AZUL}🚀 Iniciando instalación...${RESET}"
        install_tools "${missing_tools[@]}"
        
        echo -e "${AZUL}🔄 Re-verificando dependencias...${RESET}"
        sleep 2 # Pequeña pausa para que termine el proceso
        
        check_dependencies # Re-verificación REAL
        
        if [ ${#missing_tools[@]} -gt 0 ]; then
            echo -e "${ROJO}❌ ERROR CRÍTICO: No se pudieron instalar las siguientes herramientas: ${missing_tools[*]}${RESET}"
            echo -e "${AMARILLO}💡 Por favor, instálalas manualmente antes de continuar.${RESET}"
            exit 1
        else
            echo -e "${VERDE}✅ ¡Todas las dependencias instaladas correctamente!${RESET}"
        fi
    else
        echo -e "${ROJO}❌ Instalación cancelada. El script no puede continuar.${RESET}"
        exit 1
    fi
    
fi

# Comprobación de SecLists (wordlist)
# Definimos las rutas posibles
wordlist_standard="/usr/share/seclists/Discovery/Web-Content/common.txt"
wordlist_snap="/snap/seclists/current/Discovery/Web-Content/common.txt"
# Inicializamos la variable vacía
wordlist=""
# Comprobamos la ruta y definimos la variable final con la ruta correcta
if [ -f "$wordlist_standard" ]; then
    wordlist="$wordlist_standard"
elif [ -f "$wordlist_snap" ]; then
    wordlist="$wordlist_snap"
else
    # Aviso de error!!  
    echo -e "${ROJO}❌ Error: SecLists no está instalado o falta la wordlist.${RESET}"
    echo -e "${AMARILLO}💡 Puedes instalarlo de varias formas:${RESET}"
    echo -e "${VERDE}Con apt: sudo apt install seclists -y${RESET}"
    echo -e "${VERDE}Con snap: sudo snap install seclists -y${RESET}"
    echo -e "${AMARILLO}O manualmente:${RESET}"
    echo -e "${VERDE}sudo git clone --depth 1 https://github.com/danielmiessler/SecLists /usr/share/seclists${RESET}"
    echo -e -n "\n${AMARILLO}Sin SecLists no se podrán usar algunas funciones. \n¿Deseas continuar de todos modos? (s/n): ${RESET}"
    read confirm
    [[ "$confirm" != "s" ]] && exit 1
fi



# Comprobar si el objetivo es alcanzable (IP o Dominio)
echo ""
echo -e "${AZUL}🔍 Verificando conexión $target...Esto no debería llevar más de 3 segundos...${RESET}"
echo -e
if ! host "$target" &>/dev/null && ! ping -c 1 -W 1 -q "$target" &>/dev/null; then
    echo -e "${ROJO}⚠️  Atención: No se puede resolver o no hay respuesta de '$target'.${RESET}"
    echo -e -n "${AMARILLO}¿Deseas continuar de todos modos? (s/n): ${RESET}"
    read confirm
    [[ "$confirm" != "s" ]] && exit 1
fi
#Creación de carpeta y reporte .txt
folder="Auditoria_${target}_$(date +%d-%m-%Y)"
mkdir -p "$folder"
reporte_txt="$folder/Auditoria_Completa_${target}.txt"

if [ -n "$wordlist" ]; then
    echo -e "${VERDE}🔍 Comprobación SecLists instalado:      --- OK ✅${RESET}"
else
    echo -e "${ROJO} ⚠️Comprobación SecLists no instalado ❌El fuzzing web no está disponible${RESET}"
fi

echo -e "${VERDE}🔍 Comprobación de programas instalados: --- OK ✅${RESET}"
echo -e "${VERDE}🔍 Conectividad ping con host:           --- OK ✅${RESET}"
echo -e "${VERDE}🔍 Comprobación usuario ROOT:            --- OK ✅${RESET}"
sleep 1
echo
echo -e "${VERDE}✅ Sistema listo! Empezando Auditoria 🚀${RESET}"

sleep 1
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
       
        feroxbuster --url $url --wordlist "$wordlist" --extensions bak,zip,txt,sql,old,php.bak --no-recursion --filter-size 0 --threads 50 --timeout 5 | tee -a "$reporte_txt"
        
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

        wpscan --url $url$subdominio -e u,ap --detection-mode aggressive --force | tee -a "$reporte_txt"
        
        echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
        echo ""   
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        continue
    fi
done