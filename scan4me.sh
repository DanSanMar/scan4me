#!/usr/bin/env bash

export TERM=xterm-256color
umask 000   

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
dependencies=(fzf nmap whatweb feroxbuster wpscan xsltproc host arp-scan smbclient nbtscan enum4linux gobuster whois dnsrecon wafw00f sublist3r curl subfinder nuclei)

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
                "apt") 
                    sudo apt install -y "$pkg" 
                    # --- Arreglo automático exclusivo para Nuclei ---
                    if [[ "$tool" == "nuclei" ]]; then
                        echo -e "${AMARILLO}⚠️ El paquete apt de Kali suele fallar. Forzando instalación binaria oficial...${RESET}"
                        # Descargar la última versión oficial estable de GitHub para sistemas de 64 bits
                        curl -s https://api.github.com/repos/projectdiscovery/nuclei/releases/latest \
                        | grep "browser_download_url.*linux_amd64.zip" \
                        | cut -d : -f 2,3 \
                        | tr -d \" \
                        | wget -qi - -O /tmp/nuclei.zip
                        
                        # Descomprimir e instalar directamente en la ruta del sistema
                        sudo unzip -o /tmp/nuclei.zip -d /usr/bin/ nuclei
                        sudo chmod +x /usr/bin/nuclei
                        rm -f /tmp/nuclei.zip
                        # Inicializar y descargar las plantillas oficiales ---
                        echo -e "${AZUL}🔄 Descargando plantillas oficiales de Nuclei (Templates)...${RESET}"
                        sudo nuclei -update-templates
                    else
                        sudo apt install -y "$pkg"
                    fi
                    ;;
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
    # 1. Comprobar si el target está vacío
    if [ -z "$target" ]; then
        echo -e "${ROJO}❌ Error: No se ha seleccionado ningún objetivo.${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver... \e[0m'
        return
    fi

    # 2. Comprobar si el target es una IP pura. Si es una IP, no se pueden buscar subdominios.
    if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo -e "${ROJO}❌ Error: La búsqueda de subdominios requiere un DOMINIO (ej: otonesmiguelanez.com), actualmente tienes una IP asignada (${target}).${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver... \e[0m'
        return
    fi

    # 3. Comprobar diccionario
    if [ -z "$wordlist" ]; then
        echo -e "${ROJO}❌ Error: Se requiere SecLists para esta función.${RESET}"
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver... \e[0m'
        return
    fi

    # --- LIMPIEZA TOTAL Y SEGURA ---
    local dominio_limpio="${target#*://}" # Quita http:// o https:// si los hubiera
    dominio_limpio="${dominio_limpio#www.}"       # Quita www.
    dominio_limpio="${dominio_limpio%/}"          # Quita / al final
    dominio_limpio=$(echo "$dominio_limpio" | tr -d '[:space:]') # Quita espacios invisibles

    # --- CORRECCIÓN DE DICCIONARIO PARA DNS ---
    # Intentamos saltar de Web-Content a Discovery/DNS de SecLists automáticamente
    local sub_wordlist="${wordlist%/*/*}/Discovery/DNS/subdomains-top1million-5000.txt"
    if [ ! -f "$sub_wordlist" ]; then
        sub_wordlist="$wordlist" 
    fi

    if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando GoBuster DNS...${RESET}"; fi
    echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
    echo -e "🕒 INICIO SUBDOMINIOS (GoBuster): $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
    echo -e "🚀 COMANDO: gobuster dns --domain=${dominio_limpio} -w ${sub_wordlist} -t 50" | output_txt
    echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt

    # Ejecución definitiva
    gobuster dns --domain="${dominio_limpio}" -w "${sub_wordlist}" -t 50 | output_txt

    [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}✅ Resultados en: $reporte_txt${RESET}"
    echo ""
    read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
}

function procesar_reportes() {
    # Aseguramos que la carpeta existe y no está vacía
    local backup_folder="Auditoria_${target}_$(date +%d-%m-%Y)"
    local current_folder="${folder:-$backup_folder}"
    
    # Capturamos los archivos más recientes generados por la automatización
    local xml_versiones=$(ls -t "$current_folder"/nmap_auto_${target}_*_fase2.xml 2>/dev/null | head -n 1)
    local xml_vulns=$(ls -t "$current_folder"/nmap_auto_${target}_*_fase3.xml 2>/dev/null | head -n 1)
    local txt_fuzzing=$(ls -t "$current_folder"/gobuster_auto_${target}_*_fase4.txt 2>/dev/null | head -n 1)
    local txt_whatweb=$(ls -t "$current_folder"/whatweb_auto_${target}_*.txt 2>/dev/null | head -n 1)
    
    if [ -z "$xml_versiones" ]; then
        echo -e "${ROJO}⚠️ No se encontró el reporte XML base para procesar la automatización.${RESET}"
        return
    fi

    local timestamp=$(date +%H%M%S)
    local archivo_html="$current_folder/Writeup_${target}_${timestamp}.html"
    local archivo_md="$current_folder/Writeup_${target}_${timestamp}.md"
    local archivo_ia="$current_folder/ia_prompt_${target}.txt"

    # Declaración explícita de variables locales
    local total_puertos=0
    local alerta_vulns=""
    local status_web=""
    local nmap_file="${xml_versiones%.xml}.nmap"
    local vuln_file="${xml_vulns%.xml}.nmap"

    # === [CORRECCIÓN] Conteo preciso de puertos realmente ABIERTOS desde el XML ===
    if [ -f "$xml_versiones" ]; then
        total_puertos=$(grep -c 'state="open"' "$xml_versiones" 2>/dev/null)
    fi

    # Saneamiento de WhatWeb
    local whatweb_limpio=""
    if [ -f "$txt_whatweb" ] && [ -s "$txt_whatweb" ]; then
        whatweb_limpio=$(sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" "$txt_whatweb" | \
                         sed 's/], /\n/g' | \
                         sed 's/ \[\ extraction/\nextraction/g' | \
                         tr -d '[]' | \
                         grep -vE "^http" | \
                         sed 's/^[ \t]*//')
    fi

    # 1. Generar HTML unificado si xsltproc existe
    if command -v xsltproc &> /dev/null; then
        xsltproc "$xml_versiones" -o "$archivo_html" 2>/dev/null
        if [ -f "$archivo_html" ]; then
            local tmp_html="${archivo_html}.tmp"
            grep -vE "</body>|</html>" "$archivo_html" > "$tmp_html"
            
            if [ -n "$whatweb_limpio" ]; then
                {
                    echo ""
                    echo "<div id=\"web-technologies\" style=\"margin: 30px 0; padding: 20px; background: #fff; border: 1px solid #ddd; border-radius: 4px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;\">"
                    echo "  <h2 style=\"color: #4b0082; border-bottom: 2px solid #4b0082; padding-bottom: 5px; margin-top: 0;\">🔍 Tecnologías e Infraestructura Web (WhatWeb)</h2>"
                    echo "  <ul style=\"background: #fdf6e3; padding: 15px 15px 15px 35px; border-left: 5px solid #4b0082; font-family: monospace; font-size: 13px; line-height: 1.6; color: #586e75; border-radius: 4px;\">"
                    while read -r tech; do
                        [ -n "$tech" ] && echo "    <li>$tech</li>"
                    done <<< "$whatweb_limpio"
                    echo "  </ul>"
                    echo "</div>"
                } >> "$tmp_html"
            fi

            if [ -f "$txt_fuzzing" ] && [ -s "$txt_fuzzing" ]; then
                {
                    echo ""
                    echo "<div id=\"web-fuzzing\" style=\"margin: 30px 0; padding: 20px; background: #fff; border: 1px solid #ddd; border-radius: 4px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif;\">"
                    echo "  <h2 style=\"color: #005580; border-bottom: 2px solid #005580; padding-bottom: 5px; margin-top: 0;\">🌐 Fuzzing de Directorios Web (Gobuster)</h2>"
                    echo "  <pre style=\"background: #f4f4f4; padding: 15px; border-left: 5px solid #005580; overflow-x: auto; font-family: monospace; font-size: 13px; line-height: 1.5; color: #333;\">"
                    grep -vE "^=========================|^Starting gobuster|^Finished" "$txt_fuzzing" | grep -v "^$"
                    echo "  </pre>"
                    echo "</div>"
                } >> "$tmp_html"
            fi
            
            echo "</body>" >> "$tmp_html"
            echo "</html>" >> "$tmp_html"
            mv "$tmp_html" "$archivo_html"
        fi
        echo -e "${VERDE}✅ Kit de Writeup HTML generado en: ${BLANCO}$(basename "$archivo_html")${RESET}"
    fi

    # 2. Generar Markdown estructurado
    {
        echo "# 🎯 CTF Writeup / Auto-Report: $target"
        echo "📅 **Fecha de Auditoría:** $(date '+%d-%m-%Y %H:%M:%S')"
        echo "💻 **Objetivo (Target IP):** \`$target\`"
        echo ""

        if [ -f "$vuln_file" ] && grep -qiE "vulnerable|cve-|exploit" "$vuln_file"; then
            alerta_vulns="⚠️ **SÍ** (Revisa la sección 4 inmediatamente)"
        else
            alerta_vulns="✅ No se detectaron patrones obvios a primera vista"
        fi

        if [ -f "$txt_fuzzing" ] && [ -s "$txt_fuzzing" ]; then
            total_web=$(grep -vE "^====|^Start|^Finish|^$" "$txt_fuzzing" | wc -l)
            status_web="$total_web directorios/archivos encontrados"
        else
            status_web="No ejecutado o sin resultados web relevantes"
        fi

        echo "## 📝 1. Resumen Ejecutivo"
        echo "Este es un escaneo automatizado de reconocimiento rápido para el entorno CTF."
        echo ""
        echo "### 📊 Métricas Clave de la Máquina:"
        echo "- **Puertos Abiertos Detectados:** \`$total_puertos\`"
        echo "- **¿Vulnerabilidades Potenciales?:** $alerta_vulns"
        echo "- **Estado del Fuzzing Web:** \`$status_web\`"
        echo ""
        echo "💡 **Próximos pasos recomendados:**"
        if [ "$total_puertos" -gt 0 ]; then
            echo "1. Revisa la tabla de servicios abajo para buscar versiones obsoletas."
        fi
        if [ -n "$whatweb_limpio" ]; then
            echo "2. Revisa las tecnologías identificadas en la sección 5 para buscar vulnerabilidades en CMS o componentes web."
        fi
        if [ -f "$txt_fuzzing" ] && [ -s "$txt_fuzzing" ]; then
            echo "3. Examina los códigos \`200\` y \`301/302\` del Fuzzing Web en la sección 6."
        fi
        echo ""
        
        echo "## 🚪 2. Puertos y Servicios Detectados"
        echo "| Puerto | Estado | Servicio | Versión |"
        echo "| :---: | :---: | :--- | :--- |"
        
                # === [CORRECCIÓN] Evitar bucle infinito o vacío si el firewall bloqueó la Fase 2 ===
        if [ -f "$nmap_file" ] && [ "$total_puertos" -gt 0 ]; then
            # Extraemos limpiamente solo las filas de puertos, ignorando scripts inferiores, formateadas por campos
            awk '/^[0-9]+\/(tcp|udp)/ {print $1, $2, $3, $4}' "$nmap_file" | while read -r p_id p_stat p_serv p_ver_start; do
                # Capturamos la versión completa recuperando el resto de la línea original si existiera
                local full_line=$(grep "^$p_id" "$nmap_file" | head -n 1 | tr -s ' ')
                local p_ver=$(echo "$full_line" | cut -d' ' -f4-)
                
                echo "| **$p_id** | \`$p_stat\` | $p_serv | ${p_ver:-n/a} |"
            done
        elif [ -f "$nmap_file" ]; then
            echo "| - | ⚠️ ALERTA: No se encontraron puertos abiertos en Fase 2. Posible bloqueo de Firewall/IDS. | - | - |"
        else
            echo "| - | No se pudo procesar la tabla de puertos (El log RAW .nmap no está disponible). | - | - |"
        fi

        echo ""
        echo "## 🔍 3. Análisis de Versiones Detallado"
        echo "\`\`\`text"
        if [ -f "$nmap_file" ] && grep -q "PORT" "$nmap_file"; then
            sed -n '/PORT/,/Nmap done/p' "$nmap_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//'
        elif [ -f "$nmap_file" ]; then
            echo "⚠️ [FALLBACK] Nmap no reportó puertos abiertos en el formato clásico. Log crudo:"
            cat "$nmap_file"
        else
            echo "Información detallada no disponible debido a la limpieza de archivos RAW."
        fi
        echo "\`\`\`"

        if [ -f "$vuln_file" ]; then
            echo ""
            echo "## ⚡ 4. Auditoría de Vulnerabilidades (Scripts Nmap)"
            echo "\`\`\`text"
            if grep -q "PORT" "$vuln_file"; then
                sed -n '/PORT/,/Nmap done/p' "$vuln_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//'
            else
                echo "⚠️ [FALLBACK] No se extrajeron vulnerabilidades NSE porque no se detectaron puertos abiertos en esta fase."
                cat "$vuln_file"
            fi
            echo "\`\`\`"
        fi

        if [ -n "$whatweb_limpio" ]; then
            echo ""
            echo "## 🛠️ 5. Tecnologías Web Detectadas (WhatWeb)"
            while read -r tech; do
                [ -n "$tech" ] && echo "- $tech"
            done <<< "$whatweb_limpio"
        fi

        if [ -f "$txt_fuzzing" ] && [ -s "$txt_fuzzing" ]; then
            echo ""
            echo "## 🌐 6. Fuzzing de Directorios Web (Gobuster)"
            echo "\`\`\`text"
            grep -vE "^=========================|^Starting gobuster|^Finished" "$txt_fuzzing" | sed 's/^[ \t]*//' | grep -v "^$"
            echo "\`\`\`"
        fi
    } > "$archivo_md"

    echo -e "${VERDE}✅ Reporte Markdown estructurado listo en: ${BLANCO}$(basename "$archivo_md")${RESET}"

    # 3. Archivo de texto ultra-optimizado para IA (Prompt Completo)
    # === [CORRECCIÓN] Extraer solo los puertos que de verdad quedaron OPEN en el XML ===
    local ports_list=""
    if [ -f "$xml_versiones" ]; then
        ports_list=$(grep -B 1 'state="open"' "$xml_versiones" | grep "portid=" | awk -F'portid="' '{print $2}' | cut -d'"' -f1 | xargs | tr ' ' ',')
    fi

    {
        echo "ACTÚA COMO UN TUTOR EXPERTO EN CIBERSEGURIDAD Y METODOLOGÍAS CTF."
        echo "Tu objetivo es guiar de forma educativa e instructiva en el análisis de vulnerabilidades para entornos de laboratorio controlado."
        echo "Analiza el siguiente output técnico recopilado sobre el objetivo: $target"
        echo "Por favor, estructura tu respuesta detallando los siguientes puntos:"
        echo "1. **Análisis de Superficie de Ataque:** Identifica servicios detectados, versiones obsoletas y posibles malas configuraciones."
        echo "2. **Investigación Teórica (CVE):** Indica si existen vulnerabilidades conocidas asociadas a esas versiones y explica brevemente en qué consiste el fallo de seguridad."
        echo "3. **Vectores de Entrada Sugeridos:** Explica conceptualmente cómo se podría interactuar con el servicio para validar la vulnerabilidad. Presta especial atención a las rutas web descubiertas si las hay."
        echo "4. **Metodología de Explotación Educativa:** Describe la lógica o los pasos conceptuales detallados (y las herramientas estándar de la industria como curl, nmap, netcat, etc.) necesarios para comprobar el vector de ataque en un entorno controlado."
        echo "5. **Remediación y Buenas Prácticas:** Explica brevemente cómo se corregiría este fallo en un entorno de producción real."
        echo "Mantén un tono académico, técnico y didáctico. Responde en español."
        echo "--- START TARGET DATA ---"
        echo "TARGET_IP: $target"
        echo "PORTS_OPEN: ${ports_list:-Ninguno detectado abierto en Fase 2}"
        echo ""
        echo "[VERSIONS_AND_SERVICES]"
        if [ -f "$nmap_file" ] && grep -q "PORT" "$nmap_file"; then
            sed -n '/PORT/,/Nmap done/p' "$nmap_file" | grep -vE "Service detection performed|Nmap done|SF:" | sed 's/^[ \t]*//' | grep -v "^$"
        else
            echo "Fase 2 bloqueada o sin puertos abiertos. Log de Nmap:"
            [ -f "$nmap_file" ] && cat "$nmap_file"
        fi
        echo ""
        echo "[VULNERABILITY_SCRIPTS]"
        if [ -f "$vuln_file" ] && grep -q "PORT" "$vuln_file"; then
            sed -n '/PORT/,/Nmap done/p' "$vuln_file" | grep -vE "Service detection performed|Nmap done" | sed 's/^[ \t]*//' | grep -v "^$"
        else
            echo "No se encontraron scripts NSE válidos o el escaneo fue bloqueado."
        fi
        
        echo ""
        echo "[WEB_INFRASTRUCTURE_WHATWEB]"
        if [ -n "$whatweb_limpio" ]; then
            echo "$whatweb_limpio"
        else
            echo "No se detectaron tecnologías web específicas o el servicio no era HTTP."
        fi
        
        echo ""
        echo "[WEB_FUZZING_DIRECTORIES]"
        if [ -f "$txt_fuzzing" ] && [ -s "$txt_fuzzing" ]; then
            grep -vE "^=========================|^Starting gobuster|^Finished" "$txt_fuzzing" | grep -v "^$"
        else
            echo "No se detectó fuzzing web o no hubo resultados relevantes."
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
    echo -e "${BLANCO}              ░▒▓ ALL  4  M E ▓▒░ --[ V 6.4 ]--"
    echo -e "${AZUL}--[ Escaneo Interactivo de Red con multiherramientas ]--${RESET}"
    echo -e "${BLANCO}--===============================================================${RESET}"
    echo -e "${BLANCO}--[ Auto-install + Auto-scan + Nuclei + Gobuster + Nmap + ]--${RESET}"
    echo -e "${BLANCO}--[ Feroxbuster + SectList + Wpscan + OSINT + scan4windows]--${RESET}"
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
    # Creamos un menú rápido de confirmación con fzf
    local confirmar
    confirmar=$(printf "Sí, salir de scan4me\nNo, continuar en el script" | fzf \
        --prompt="⚠️ ¿Seguro que deseas salir del script? " \
        --height=10% --layout=reverse --border)

    # Si elige "Sí" o si vuelve a pulsar Ctrl+C/ESC en esta pantalla, el script se cierra de verdad
    if [[ "$confirmar" == *"Sí"* || -z "$confirmar" ]]; then
        echo -e "\n"
        echo -e "${AZUL}%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%${RESET}"
        echo -e "${BLANCO}     ¡Gracias por usar scan4me! Bye!      ${RESET}"
        echo -e "${AZUL}%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%${RESET}"
        exit 0
    else
        # Si elige "No", simplemente limpiamos la pantalla actual y no hacemos 'exit'.
        # Al no hacer exit, el flujo del script continuará en el menú donde lo dejaste.
        clear
    fi
}

# Nueva función para manejar el Ctrl+C sin cerrar el script
function interrupcion() {
    echo -e "\n\n${ROJO}⚠️ Acción cancelada por el usuario.${RESET}"
    echo -e "${AMARILLO}[!] Pulse Enter para continuar...${RESET}\n"
    sleep 0.5
    # Al no poner 'exit', Bash continuará con el bucle 'while true' principal
}

# Asignamos la interrupción al SIGINT (Ctrl+C)
trap interrupcion SIGINT

# Comprobación usuario root
if [[ $EUID -ne 0 ]]; then
   echo -e "${ROJO}❌ Este script debe ejecutarse con sudo.${RESET}" 
   echo -e "${AMARILLO}Ejemplo: sudo $0 10.10.10.1${RESET}"
   exit 1
fi
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
        # 1. Comprobación estándar en el PATH actual
        if command -v "$tool" &> /dev/null; then
            continue
        fi
        
        # 2. Comprobación en rutas de Snap
        if [ -f "/snap/bin/$tool" ] || [ -f "/var/lib/snapd/snap/bin/$tool" ]; then
            continue
        fi

        # 3. Arreglo específico para Nuclei en Kali Real (VirtualBox/Baremetal)
        if [[ "$tool" == "nuclei" ]]; then
            # Rutas comunes donde Kali/Go guardan nuclei
            if [ -f "/usr/bin/nuclei" ] || [ -f "/usr/local/bin/nuclei" ] || [ -f "/root/go/bin/nuclei" ] || [ -f "/home/kali/go/bin/nuclei" ]; then
                # Si existe físicamente en alguna, creamos un alias en caliente para esta sesión del script
                if [ -f "/root/go/bin/nuclei" ] && [ ! -f "/usr/bin/nuclei" ]; then
                    ln -sf /root/go/bin/nuclei /usr/bin/nuclei 2>/dev/null
                elif [ -f "/home/kali/go/bin/nuclei" ] && [ ! -f "/usr/bin/nuclei" ]; then
                    ln -sf /home/kali/go/bin/nuclei /usr/bin/nuclei 2>/dev/null
                fi
                continue
            fi
        fi

        # Si no pasó ninguna validación, se añade a faltantes
        missing_tools+=("$tool")
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
#Creación de carpeta y reporte .txt (Sanitizando rutas para evitar errores con barra /)
target_safe=$(echo "$target" | tr '/' '_')
folder="A_${target_safe}_$(date +%d-%m-%Y)"
mkdir -p "$folder"
reporte_txt="$folder/A_${target_safe}.txt"

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
NUCLEI_BIN=$(command -v nuclei || echo "/usr/bin/nuclei")

[[ ! -x "$FEROX_BIN" ]] && FEROX_BIN="feroxbuster" 
[[ ! -x "$WPSCAN_BIN" ]] && WPSCAN_BIN="wpscan"
[[ ! -x "$NUCLEI_BIN" ]] && NUCLEI_BIN="/root/go/bin/nuclei"
[[ ! -x "$NUCLEI_BIN" ]] && NUCLEI_BIN="nuclei"

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
        "1.  Auto-Scan recomendado para CTF     | (-p- -sSCV + Vuln + Whatweb + Fuzzing)"
        "2.  Nuclei (Submenú)                   | nuclei"
        "3.  Nmap, otras opciones (Submenú)     | nmap"
        "4.  Whatweb (Reconocimiento web)       | whatweb"
        "5.  Gobuster (Fuzzing Subdominios)     | subdomains"
        "6.  Feroxbuster (Submenú fuzzing)      | feroxbuster"    
        "7.  Wpscan (reconocimiento wordpress)  | wpscan" 
        "8.  Más opciones Windows(Submenú)      | windows"
        "9.  Herramientas OSINT (Submenú)       | footprinting" 
        "x.            -- SALIR --              | exit"
    )

    selection=$(printf "%s\n" "${options[@]}" | fzf --prompt="🔍 Selecciona el tipo de acción: " --height=18% --layout=reverse --border)
    
    if [ -z "$selection" ]; then
        despedida
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

    # --- OPCIÓN 1: ESCANEO AUTOMÁTICO OPTIMIZADO PARA CTF ---
    if [[ "$selection" == *"1."* ]] || [[ "$selection" == *"Automático"* ]]; then
        echo -e "\n${AZUL}🚀 [Fase 1] Descubrimiento ultra-rápido de puertos abiertos...${RESET}"
        flags="-sS -p- -n -Pn --open --min-rate 5000"

        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO AUTO-SCAN FASE 1: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        echo -e "🚀 COMANDO: nmap $flags $target" | output_txt
        echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        
        # Guardamos temporalmente para extraer los puertos abiertos
        nmap $flags "$target" | tee /tmp/scan4me_fase1.txt
        cat /tmp/scan4me_fase1.txt | output_txt
        open_ports=$(grep "/tcp" /tmp/scan4me_fase1.txt | cut -d/ -f1 | xargs | tr ' ' ',')
        rm -f /tmp/scan4me_fase1.txt
        
        if [ -z "$open_ports" ]; then
            echo -e "\n${ROJO}❌ No se encontraron puertos abiertos con tasas agresivas.${RESET}" | output_txt
            echo -e "${CYAN}⚠️ Reintentando con evasión genérica y temporizado seguro...${RESET}" | output_txt
            
            flags_sigilo="-sF --top-ports 1000 -Pn -n --open -T3 --data-length 25"
            
            echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO ESCANEO SIGILOSO: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: nmap $flags_sigilo $target" | output_txt
            echo -e "${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
            
            nmap $flags_sigilo "$target" | tee /tmp/scan4me_sigilo.txt
            cat /tmp/scan4me_sigilo.txt | output_txt
            open_ports=$(grep "/tcp" /tmp/scan4me_sigilo.txt | cut -d/ -f1 | xargs | tr ' ' ',')
            rm -f /tmp/scan4me_sigilo.txt
            
            if [ -z "$open_ports" ]; then
                echo -e "\n${ROJO}❌ No se detectaron servicios activos. El host podría estar blindado o caído.${RESET}" | output_txt
                echo ""
                read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
                continue
            fi
        fi

        echo -e "\n${VERDE}✅ Puertos objetivos identificados: $open_ports${RESET}" | output_txt

        # Definición estricta de marcas de tiempo y rutas sincronizadas con procesar_reportes()
        current_time=$(date +%H%M%S)
        archivo_fase2="$folder/nmap_auto_${target}_${current_time}_fase2"
        archivo_fase3="$folder/nmap_auto_${target}_${current_time}_fase3"
        archivo_fase4="$folder/gobuster_auto_${target}_${current_time}_fase4"

        # --- FASE 2: VERSIONES Y SERVICIOS COMPLETOS ---
        echo -e "\n${AZUL}🚀 [Fase 2] Analizando versiones exactas y banners en puertos activos...${RESET}"
        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO DETECCIÓN VERSIONES: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        
        if [[ "$xml_status" == "ON" ]]; then
            echo -e "🚀 COMANDO: nmap -sSCV -Pn -n -p $open_ports $target -oA $archivo_fase2" | output_txt
            nmap -sSCV -Pn -n -p "$open_ports" "$target" -oA "$archivo_fase2"
            [ -f "${archivo_fase2}.nmap" ] && cat "${archivo_fase2}.nmap" | output_txt
        else
            echo -e "🚀 COMANDO: nmap -sSCV -Pn -n -p $open_ports $target" | output_txt
            nmap -sSCV -Pn -n -p "$open_ports" "$target" | output_txt
        fi

        # --- FASE 3: AUDITORÍA DETALLADA DE VULNERABILIDADES (NSE) ---
        echo -e "\n${AZUL}🚀 [Fase 3] Corriendo batería de scripts NSE orientados a vulnerabilidades conocidas...${RESET}"
        echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
        echo -e "🕒 INICIO AUDITORÍA NSE VULN: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
        
        if [[ "$xml_status" == "ON" ]]; then
            echo -e "🚀 COMANDO: nmap --script vuln -Pn -n --script-args=unsafe=1 -p $open_ports $target -oA $archivo_fase3" | output_txt
            nmap --script vuln -Pn -n --script-args=unsafe=1 -p "$open_ports" "$target" -oA "$archivo_fase3"
            [ -f "${archivo_fase3}.nmap" ] && cat "${archivo_fase3}.nmap" | output_txt
        else
            echo -e "🚀 COMANDO: nmap --script vuln -Pn -n --script-args=unsafe=1 -p $open_ports $target" | output_txt
            nmap --script vuln -Pn -n --script-args=unsafe=1 -p "$open_ports" "$target" | output_txt
        fi

        # --- FASE 4: ANÁLISIS WEB INTELIGENTE ---
        if echo "$open_ports" | grep -qE "(^|,)(80|443|8080|8443)(,|$)"; then
            # Definimos la ruta del archivo para almacenar WhatWeb
            archivo_whatweb="$folder/whatweb_auto_${target}_${current_time}"

            echo -e "\n${AZUL}🚀 [Fase 4] Entorno Web Detectado. Analizando tecnologías con WhatWeb...${RESET}"
            echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO AUTOMÁTICO WHATWEB: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            
            if [[ "$xml_status" == "ON" ]]; then
                echo -e "🚀 COMANDO: whatweb -a 1 -t 1 -v --no-errors $target (Guardando en reporte)" | output_txt
                # Lanzamos whatweb, guardamos en archivo para el reporte y mandamos al log general
                whatweb -a 1 -t 1 -v --no-errors "$target" | tee "${archivo_whatweb}.txt" | output_txt
            else
                echo -e "🚀 COMANDO: whatweb -a 1 -t 1 -v --no-errors $target" | output_txt
                whatweb -a 1 -t 1 -v --no-errors "$target" | output_txt
            fi
            echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
            if [ -n "$wordlist" ] && [ -f "$wordlist" ]; then
                echo -e "\n${AZUL}🔍 Lanzando Fuzzing Web Estructurado con Gobuster...${RESET}"
                echo -e "\n${AZUL}══════════════════════════════════════════════════${RESET}" | output_txt
                echo -e "🕒 INICIO FUZZING: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
                
                if [[ "$xml_status" == "ON" ]]; then
                    echo -e "🚀 COMANDO: gobuster dir -u http://$target/ -w $wordlist -t 40 -q -o ${archivo_fase4}.txt" | output_txt
                    gobuster dir -u "http://$target/" -w "$wordlist" -t 40 -q -o "${archivo_fase4}.txt"
                    [ -f "${archivo_fase4}.txt" ] && cat "${archivo_fase4}.txt" | output_txt
                else
                    echo -e "🚀 COMANDO: gobuster dir -u http://$target/ -w $wordlist -t 40 -q" | output_txt
                    gobuster dir -u "http://$target/" -w "$wordlist" -t 40 -q | output_txt
                fi
            else
                echo -e "\n${AMARILLO}⚠️ Fuzzing omitido: Diccionario global SecLists no disponible.${RESET}" | output_txt
            fi
        else
            echo -e "\n${AMARILLO}⏳ Saltando Fase Web: Los puertos HTTP/HTTPS estándar están cerrados.${RESET}" | output_txt
        fi

        # --- PROCESADO DE WRITEUPS E INFORME FINAL ---
        if [[ "$xml_status" == "ON" ]]; then
            # LLamada segura a tu función de generación de reportes Markdown/HTML/IA
            procesar_reportes

            echo -e "${AZUL}--------------------------------------------------${RESET}"
            echo -e "${VERDE}✅ Estructuras de reportes dinámicos procesadas con éxito en: $folder${RESET}"
            echo -e "${AZUL}--------------------------------------------------${RESET}"
            echo -e "${AMARILLO}📌 Si deseas retener los volcados RAW xml/txt originales de Nmap, pulsa: Ctrl+C${RESET}"
            read -n 1 -s -r -p $'\e[1;32m🚀 Para aplicar limpieza automática de logs RAW y dejar solo los Writeups refinados pulsa: Enter\e[0m'

            # Limpieza higiénica selectiva solo si el usuario decide continuar con Enter
            rm -f "${archivo_fase2}.xml" "${archivo_fase2}.nmap" "${archivo_fase2}.gnmap"
            rm -f "${archivo_fase3}.xml" "${archivo_fase3}.nmap" "${archivo_fase3}.gnmap"
            rm -f "${archivo_fase4}.txt"
            rm -f "${archivo_whatweb}.txt"
        fi

        echo -e "\n${VERDE}🏁 Proceso de Auditoría Automática Completado.${RESET}"
        [[ "$txt_status" == "ON" ]] && echo -e "${VERDE}📄 Archivo log unificado disponible en: $reporte_txt${RESET}"
        echo ""
        read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú principal...\e[0m'
        continue
    fi 


    # --- OPCIÓN 9: SUBMENÚ NUCLEI ---
    if [[ "$selection" == *"nuclei"* ]] || [[ "$selection" == *"Nuclei"* ]]; then
        # Rastreo físico del binario para entornos VirtualBox / Sudo
        if command -v nuclei &> /dev/null; then
            NUCLEI_BIN=$(command -v nuclei)
        elif [ -f "/usr/bin/nuclei" ]; then
            NUCLEI_BIN="/usr/bin/nuclei"
        elif [ -f "/usr/local/bin/nuclei" ]; then
            NUCLEI_BIN="/usr/local/bin/nuclei"
        elif [ -f "/root/go/bin/nuclei" ]; then
            NUCLEI_BIN="/root/go/bin/nuclei"
        elif [ -f "/home/kali/go/bin/nuclei" ]; then
            NUCLEI_BIN="/home/kali/go/bin/nuclei"
        else
            NUCLEI_BIN="nuclei"
        fi

        while true; do
            mostrar_logo  # Limpia la pantalla y redibuja tu banner superior
            echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
            
            # Formateamos el target para que Nuclei siempre reciba un formato URL válido (http/https)
            url_nuclei="$target"
            if [[ ! "$url_nuclei" =~ ^https?:// ]]; then
                url_nuclei="http://$url_nuclei"
            fi

            sub_options=(
                "1.  [🤖 AUTO] Escaneo Inteligente Tecnológico (-as)       | -as"
                "2.  [🔥 CRÍTICO] Solo severidades Crítica y Alta          | -severity critical,high"
                "3.  [🛡️ COMPLETO] Escaneo Estándar (Todas las plantillas) | "
                "4.  [🏷️ TAGS] Escaneo por etiquetas (cve, panel, tech)    | -tags cve,panel,tech"
                "5.  [🔄 UPDATE] Actualizar motor y plantillas YAML        | -update-templates"
                "x.  -- Volver al menú principal...                        | back"
            )

            sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="☢️ Perfiles de Nuclei: " --height=25% --layout=reverse --border)

            # Control de salida rápido con un solo Ctrl+C o ESC
            if [ -z "$sub_selection" ]; then
                despedida
            fi

            # Control voluntario para volver atrás
            if [[ "$sub_selection" == *"Volver"* || "$sub_selection" == *"back"* ]]; then
                break
            fi

            # Extraemos los argumentos específicos de Nuclei a la derecha del pipe '|'
            nuclei_args=$(echo "$sub_selection" | awk -F "|" '{print $2}' | xargs)

            # Generamos nombres de reporte limpios basados en marcas de tiempo
            nuclei_timestamp=$(date +%H%M%S)
            # CORRECCIÓN: Cambiado $nuclei_nuclei_timestamp por $nuclei_timestamp para que use la variable correcta
            reporte_nuclei_txt="$folder/nuclei_${target_safe}_${nuclei_timestamp}.txt"
            reporte_nuclei_json="$folder/nuclei_${target_safe}_${nuclei_timestamp}.json"

            # Si la opción elegida es solo actualizar plantillas, no concatenamos el target
            if [[ "$sub_selection" == *"Actualizar"* ]]; then
                cmd_raw="$NUCLEI_BIN $nuclei_args"
            else
                # Construimos el comando base dependiendo de si se requiere guardar reporte dedicado
                if [[ "$xml_status" == "ON" ]]; then
                    cmd_raw="$NUCLEI_BIN -u $url_nuclei $nuclei_args -json-export $reporte_nuclei_json"
                elif [[ "$txt_status" == "ON" ]]; then
                    cmd_raw="$NUCLEI_BIN -u $url_nuclei $nuclei_args -o $reporte_nuclei_txt"
                else
                    cmd_raw="$NUCLEI_BIN -u $url_nuclei $nuclei_args"
                fi
            fi

            if [[ "$txt_status" == "OFF" ]]; then 
                echo -e "${AMARILLO}⏳ Ejecutando Nuclei... Esto puede demorar según el perfil.${RESET}"
            fi

            # Encabezado para tu archivo de LOG unificado
            echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO NUCLEI: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: $cmd_raw" | output_txt
            echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt

            # Ejecutamos el comando de forma segura
            eval "$cmd_raw" 2>&1 | output_txt

            # Avisos de finalización y guardado
            if [[ "$xml_status" == "ON" && ! "$sub_selection" == *"Actualizar"* ]]; then
                echo -e "\n${VERDE}🌐 Reporte estructurado JSON guardado en: $reporte_nuclei_json${RESET}"
            elif [[ "$txt_status" == "ON" && ! "$sub_selection" == *"Actualizar"* ]]; then
                # Si guardó en un TXT dedicado, adjuntamos opcionalmente su contenido al log general
                if [ -f "$reporte_nuclei_txt" ]; then
                    cat "$reporte_nuclei_txt" >> "$reporte_txt"
                fi
                echo -e "\n${VERDE}✅ Reporte limpio guardado en: $reporte_nuclei_txt${RESET}"
            fi

            [[ "$txt_status" == "ON" ]] && echo -e "${VERDE}📄 Log unificado actualizado en: $reporte_txt${RESET}"
            
            # Pausa obligatoria antes de que 'mostrar_logo' limpie la pantalla
            echo -e "\n${AMARILLO}Presiona [ENTER] para regresar al submenú de Nuclei...${RESET}"
            read -r
        done
        continue
    fi
    # --- OPCIÓN : SUBMENÚ NMAP ---
    if [[ "$selection" == *"Nmap, otras opciones (Submenú)"* ]]; then
        while true; do
            mostrar_logo
            echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
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
                "12. [MANUAL INTERACTIVO] Elige tu mismo      | custom"
                "b. << Volver al menú principal"
            )
            
            # Usamos una variable separada (sub_selection) para no pisar la lógica global
            sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="🛠 Opciones de Nmap: " --height=25% --layout=reverse --border)
            
            [[ -z "$sub_selection" ]] && break
            [[ "$sub_selection" == *"Volver"* ]] && break

            flags=$(echo "$sub_selection" | awk -F "|" "{print \$2}" | xargs)

            # --- LÓGICA DE ESCANEO CUSTOM CON FZF  ---
            if [[ "$flags" == "custom" ]]; then
                # Paso 1: Tipo de Escaneo
                scan_opts=(
                    "1. SYN Stealth Scan (Recomendado) | -sS"
                    "2. TCP Connect Scan (Sin privilegios) | -sT"
                    "3. UDP Scan (Lento) | -sU"
                    "4. ACK Scan (Mapeo de Firewall) | -sA"
                )
                sel_scan=$(printf "%s\n" "${scan_opts[@]}" | fzf --prompt="🛡️ 1/5 - Selecciona Tipo de Escaneo: " --layout=reverse --height=15% --border)
                custom_scan=$(echo "$sel_scan" | awk -F "|" '{print $2}' | xargs)
                [[ -z "$custom_scan" ]] && custom_scan="-sS"

                # Paso 2: Selección de Puertos
                port_opts=(
                    "1. Top 100 Puertos Rápidos | -F"
                    "2. Puertos estándar (Top 1000) | "
                    "3. Todos los Puertos (65535) | -p-"
                    "4. Puertos Web + Comunes (80,443,22,21,445,8080) | -p 21,22,80,443,445,8080"
                )
                sel_port=$(printf "%s\n" "${port_opts[@]}" | fzf --prompt="🔢 2/5 - Selecciona Rango de Puertos: " --layout=reverse --height=15% --border)
                custom_port=$(echo "$sel_port" | awk -F "|" '{print $2}' | xargs)

                # Paso 3: Versiones y Scripts (Detección avanzada)
                script_opts=(
                    "1. Solo escaneo de puertos (Sin detección) | "
                    "2. Detectar Versiones de Servicios (-sV) | -sV"
                    "3. Scripts por Defecto y Versiones (-sC -sV) | -sC -sV"
                    "4. Analizar Vulnerabilidades Frecuentes (--script vuln) | -sV --script vuln"
                )
                sel_script=$(printf "%s\n" "${script_opts[@]}" | fzf --prompt="⚙️ 3/5 - Scripts y Versiones: " --layout=reverse --height=15% --border)
                custom_script=$(echo "$sel_script" | awk -F "|" '{print $2}' | xargs)

                # Paso 4: Tiempos / Agresividad
                time_opts=(
                    "1. T3 (Normal / Evadir alertas simples) | -T3"
                    "2. T4 (Rápido / Recomendado en entornos controlados) | -T4"
                    "3. T5 (Muy Agresivo / Puede perder paquetes) | -T5"
                )
                sel_time=$(printf "%s\n" "${time_opts[@]}" | fzf --prompt="⚡ 4/5 - Plantilla de Tiempos (Timing): " --layout=reverse --height=15% --border)
                custom_time=$(echo "$sel_time" | awk -F "|" '{print $2}' | xargs)
                [[ -z "$custom_time" ]] && custom_time="-T4"

                # Paso 5: Evasión / Optimización (Permite multi-selección con TAB como en Feroxbuster)
                evasion_opts=(
                    "-Pn (No realizar ping antes del escaneo)"
                    "-n (No realizar resolución DNS inversa para agilizar)"
                    "-v (Incrementar nivel de verbosidad en el log)"
                    "--open (Mostrar únicamente puertos con estado abierto)"
                )
                sel_evasion=$(printf "%s\n" "${evasion_opts[@]}" | fzf -m --prompt="🧩 5/5 - Parámetros extra (TAB=Seleccionar, ENTER=Confirmar): " --layout=reverse --height=20% --border)
                
                if [[ -z "$sel_evasion" ]]; then
                    custom_evasion=""
                else
                    # Filtramos solo el flag (lo que está antes del espacio) de cada línea seleccionada
                    custom_evasion=$(echo "$sel_evasion" | awk '{print $1}' | xargs)
                fi

                # Unimos todos los flags interactivos seleccionados
                flags="$custom_scan $custom_port $custom_script $custom_time $custom_evasion"
                
                # Limpiamos espacios dobles residuales
                flags=$(echo "$flags" | tr -s ' ')
            fi
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
            
            echo ""
            read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para continuar en este submenú...\e[0m'
                
        done 
        continue
    fi

    # --- OPCIÓN 8 : WHATWEB ---
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
    # --- SUBMENÚ FEROXBUSTER (AMPLIADO Y ORDENADO POR CATEGORÍAS) ---
    if [[ "$selection" == *"Feroxbuster"* ]]; then
        while true; do
            mostrar_logo
            echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
            
            if [ -z "$wordlist" ]; then
                echo -e "${ROJO}❌ Error: No puedes usar Feroxbuster sin el diccionario SecLists.${RESET}"
                read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
                continue
            fi
            
            sl_base="${wordlist%/Discovery/Web-Content/common.txt}"
            [[ -z "$sl_base" || ! -d "$sl_base" ]] && sl_base="/usr/share/seclists"

            sub_options=(
                "1.  [⚡ RÁPIDO] Fuzzing Básico (common.txt)                      | --wordlist $wordlist --threads 50 --no-recursion"
                "2.  [📁 CLÁSICO CTF] Dirbuster Medium (Solo Directorios)         | --wordlist $sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt --threads 50 --depth 2"
                "3.  [🚀 FULL CTF] Dirbuster Medium + Ext (php,html,txt)          | --wordlist $sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt --extensions php,html,txt --threads 50 --depth 2"
                "4.  [🐧 TECH] Entorno LAMP (Apache / PHP)                        | --wordlist $sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt --extensions php,txt --threads 50 --no-recursion"
                "5.  [🪟 TECH] Entorno IIS (Windows / ASP)                        | --wordlist $sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt --extensions asp,aspx,config,txt --threads 50 --no-recursion"
                "6.  [☕ TECH] Entorno Java (Tomcat / Spring)                     | --wordlist $sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt --extensions jsp,do,action --threads 50 --no-recursion"
                "7.  [⚙️  TECH] Scripts CGI-BIN (Shellshock)                       | --wordlist $wordlist --extensions cgi,sh,pl,py --threads 50 --no-recursion"
                "8.  [🗄️  ARCHIVOS] Búsqueda de Backups y Configs Ocultas          | --wordlist $sl_base/Discovery/Web-Content/raft-large-files.txt --extensions bak,old,zip,tar.gz,sql,db,swp --threads 50 --no-recursion"
                "9.  [🔌 API] Fuzzing de Endpoints API                            | --wordlist $sl_base/Discovery/Web-Content/api/api-endpoints.txt --threads 50 --no-recursion"
                "10. [🎯 DICCIONARIO] Raft Large (Directorios Profundos)          | --wordlist $sl_base/Discovery/Web-Content/raft-large-directories.txt --threads 50 --depth 2"
                "11. [🥷 EVASIÓN] Modo Sigiloso / WAF (Random Agent, 1 Hilo)      | --wordlist $wordlist --extensions php,html,txt --threads 1 --timeout 15 --rate-limit 2 --random-agent --no-recursion"
                "12. [🛠️  A MEDIDA] Configurar Fuzzing Manualmente...              | custom"
                "x.  << Volver al menú principal                                  | back"
            )
            
            sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="🌐 Perfiles Avanzados de Feroxbuster: " --height=25% --layout=reverse --border)
            
            [[ -z "$sub_selection" ]] && break
            [[ "$sub_selection" == *"Volver"* || "$sub_selection" == *"back"* ]] && break
            
            profile_args=$(echo "$sub_selection" | awk -F "|" '{print $2}' | xargs)
            
            # --- LÓGICA DE FUZZING A MEDIDA CON FZF ---
            if [[ "$profile_args" == "custom" ]]; then
                dict_medium="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
                [[ ! -f "$dict_medium" ]] && dict_medium="$sl_base/Discovery/Web-Content/directory-list-2.3-medium.txt"
                dict_files="$sl_base/Discovery/Web-Content/raft-large-files.txt"
                dict_api="$sl_base/Discovery/Web-Content/api/api-endpoints.txt"
                dict_cgi="$sl_base/Discovery/Web-Content/CGIs.txt"

                dict_opts=(
                    "1. Básico (common.txt)                   | $wordlist"
                    "2. Medio (directory-list-2.3-medium.txt) | $dict_medium"
                    "3. Archivos (raft-large-files.txt)       | $dict_files"
                    "4. APIs (api-endpoints.txt)              | $dict_api"
                    "5. Vulnerabilidades (cgis.txt)           | $dict_cgi"
                )
                
                sel_dict=$(printf "%s\n" "${dict_opts[@]}" | fzf --prompt="📖 1/4 - Selecciona Diccionario: " --layout=reverse --height=15% --border)
                custom_dict=$(echo "$sel_dict" | awk -F "|" '{print $2}' | xargs)
                [[ -z "$custom_dict" ]] && custom_dict="$wordlist" 
                          
                ext_opts=( "php" "html" "txt" "js" "bak" "zip" "tar.gz" "sql" "swp" "asp" "aspx" "config" "jsp" "do" "action" "sh" "cgi" "pl" "py" )
                sel_ext=$(printf "%s\n" "${ext_opts[@]}" | fzf -m --prompt="🧩 2/4 - Multi-Selección con TAB (ENTER=Aceptar, ESC=Ninguna): " --layout=reverse --height=25% --border)
                
                if [[ -z "$sel_ext" ]]; then
                    custom_ext=""
                else
                    ext_joined=$(echo "$sel_ext" | paste -sd "," -)
                    custom_ext="--extensions $ext_joined"
                fi

                thread_opts=("10 (Lento/Seguro)" "50 (Equilibrado)" "100 (Agresivo)" "200 (Modo Dios)")
                sel_threads=$(printf "%s\n" "${thread_opts[@]}" | fzf --prompt="⚡ 3/4 - Selecciona Hilos: " --layout=reverse --height=12% --border)
                custom_threads=$(echo "$sel_threads" | awk '{print $1}')
                [[ -z "$custom_threads" ]] && custom_threads="50"

                rec_opts=("No Recursivo (--no-recursion)" "Recursividad Nivel 2 (--depth 2)" "Recursividad Nivel 3 (--depth 3)")
                sel_rec=$(printf "%s\n" "${rec_opts[@]}" | fzf --prompt="📁 4/4 - Profundidad / Recursividad: " --layout=reverse --height=10% --border)
                if [[ "$sel_rec" == *"No"* || -z "$sel_rec" ]]; then
                    custom_rec="--no-recursion"
                elif [[ "$sel_rec" == *"Nivel 2"* ]]; then
                    custom_rec="--depth 2"
                elif [[ "$sel_rec" == *"Nivel 3"* ]]; then
                    custom_rec="--depth 3"
                fi

                profile_args="--wordlist $custom_dict --threads $custom_threads $custom_ext $custom_rec"
                echo -e "\n${VERDE}✅ Configuración generada:${RESET} $profile_args\n"
                sleep 1
            fi
            # --- FIN LÓGICA A MEDIDA ---

            url="$target"
            if [[ ! "$url" =~ ^https?:// ]]; then url="http://$url"; fi

            target_safe=$(echo "$target" | tr '/' '_')
            ferox_timestamp=$(date +%H%M%S)
            ferox_txt="$folder/feroxbuster_${target_safe}_${ferox_timestamp}.txt"
            ferox_json="$folder/feroxbuster_${target_safe}_${ferox_timestamp}.json"

            if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando feroxbuster...${RESET}"; fi
            
            echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO feroxbuster: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            
            read -r -a custom_args <<< "$profile_args"
            cmd_args=("--url" "$url" "--filter-size" "0" "${custom_args[@]}")

            if [[ "$xml_status" == "ON" ]]; then
                echo -e "🚀 COMANDO: feroxbuster ${cmd_args[*]} --json --output $ferox_json" | output_txt
                echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt
                $FEROX_BIN "${cmd_args[@]}" --json --output "$ferox_json"
                
                if [[ "$txt_status" == "ON" ]] && [ -f "$ferox_json" ]; then
                    {
                        echo ""
                        echo "🌐 [Resultados extraídos de Feroxbuster JSON]:"
                        grep '"status"' "$ferox_json" | while read -r line; do
                            status=$(echo "$line" | grep -o '"status":[0-9]*' | cut -d':' -f2)
                            v_url=$(echo "$line" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
                            if [ -n "$v_url" ]; then echo "   [+] $status - $v_url"; fi
                        done
                        echo ""
                    } >> "$reporte_txt"
                fi
                echo -e "\n${VERDE}🌐 Reporte estructurado JSON guardado en: $ferox_json${RESET}"
            else
                if [[ "$txt_status" == "ON" ]]; then
                    echo -e "🚀 COMANDO: feroxbuster ${cmd_args[*]} --output $ferox_txt" | output_txt
                    echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt
                    $FEROX_BIN "${cmd_args[@]}" --output "$ferox_txt"
                    if [ -f "$ferox_txt" ]; then cat "$ferox_txt" >> "$reporte_txt"; fi
                    echo -e "\n${VERDE}✅ Resultados individuales limpios en: $ferox_txt${RESET}"
                else
                    echo -e "🚀 COMANDO: feroxbuster ${cmd_args[*]}" | output_txt
                    echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt
                    $FEROX_BIN "${cmd_args[@]}"
                fi
            fi
            
            [[ "$txt_status" == "ON" ]] && echo -e "${VERDE}📄 Log unificado actualizado en: $reporte_txt${RESET}"
            echo ""
            read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al submenú de Feroxbuster...\e[0m'
        done
        continue
    fi
    # --- OPCIÓN 10: SUBMENÚ WPSCAN ---
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
    # --- OPCIÓN 11: SUBMENÚ SUBDOMINIOS ---
    if [[ "$selection" == *"subdomains"* ]] || [[ "$selection" == *"Gobuster"* ]]; then
        buscar_subdominios
        continue
    fi

    # --- OPCIÓN 6: SUBMENÚ WINDOWS ---
    if [[ "$selection" == *"windows"* ]]; then
        while true; do
            mostrar_logo
            echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
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
            
            [[ -z "$sub_selection" ]] && break
            [[ "$sub_selection" == *"Volver"* ]] && break
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
        done
        continue
    fi

        # --- OPCIÓN 8: SUBMENÚ RECONOCIMIENTO PASIVO (FOOTPRINTING) ---
    if [[ "$selection" == *"footprinting"* ]]; then
        while true; do
            mostrar_logo
            echo -e "${VERDE}🎯 Objetivo actual: ${BLANCO}$target${RESET} | ${AZUL}XML: ${xml_color}[$xml_status]${RESET} | ${MAGENTA}Guardar TXT: ${txt_color}[$txt_status]${RESET}\n"
        # 1. Limpieza estricta para herramientas de dominio (WHOIS, DNSRecon, Sublist3r, Subfinder)
        dominio_limpio="${target#*://}"
        dominio_limpio="${dominio_limpio#www.}" 
        dominio_limpio="${dominio_limpio%/}"

        # 2. Construcción INTELIGENTE de la URL para herramientas Web (WAFW00F)
        # Extraemos lo que hay después del protocolo, pero CONSERVANDO el 'www.' si existía
        host_web="${target#*://}"
        host_web="${host_web%/}"

        url_osint="$target"
            if [[ ! "$url_osint" =~ ^https?:// ]]; then
                # Si el host_web tiene forma de IP pura
                if [[ "$host_web" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    url_osint="http://$host_web"
                else
                    # Si es un dominio, respetamos si lleva www. o no y usamos HTTPS
                    url_osint="https://$host_web"
                fi
            fi

            # 3. Comprobamos si el host web es una IP para bifurcar el menú
            if [[ "$host_web" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                # MENÚ RESTRINGIDO PARA IPs
                sub_options=(
                    "1.  [WHOIS] Registro y Contactos del ASN/IP      | whois $host_web"
                    "2.  [WAFW00F] Detección de Firewall Web (WAF)    | wafw00f $url_osint"
                    "3.  [OSINT] Reverse IP Lookup (HackerTarget)     | curl -s https://api.hackertarget.com/reverseiplookup/?q=$host_web"
                    "x.  << Volver al menú principal                  | back"
                )
                prompt_text="🕵️ OSINT (Modo IP): "
            else
                # MENÚ COMPLETO PARA DOMINIOS (Incluye Sublist3r y el nuevo Subfinder)
                sub_options=(
                    "1.  [WHOIS] Registro y Contactos del Dominio     | whois $dominio_limpio"
                    "2.  [DNSRecon] Enumeración DNS estándar          | dnsrecon -d $dominio_limpio"
                    "3.  [WAFW00F] Detección de Firewall Web (WAF)    | wafw00f $url_osint"
                    "4.  [Sublist3r] Búsqueda OSINT de Subdominios    | sublist3r -d $dominio_limpio"
                    "5.  [Subfinder] Descubrimiento Pasivo de Hosts   | subfinder -d $dominio_limpio"
                    "6.  [OSINT] Búsqueda de Hosts (HackerTarget)     | curl -s https://api.hackertarget.com/hostsearch/?q=$dominio_limpio"
                    "x.  << Volver al menú principal                  | back"
                )
                prompt_text="🕵️ OSINT (Modo Dominio): "
            fi
            
            sub_selection=$(printf "%s\n" "${sub_options[@]}" | fzf --prompt="$prompt_text" --height=25% --layout=reverse --border)
            
            [[ -z "$sub_selection" ]] && break
            [[ "$sub_selection" == *"Volver"* ]] && break
            # Extraemos el comando a ejecutar (lo que está a la derecha del '|')
            cmd_raw=$(echo "$sub_selection" | awk -F "|" '{print $2}' | xargs)

            if [[ "$txt_status" == "OFF" ]]; then echo -e "${AMARILLO}⏳ Ejecutando herramienta de footprinting...${RESET}"; fi
            
            echo -e "\n${MAGENTA}══════════════════════════════════════════════════${RESET}" | output_txt
            echo -e "🕒 INICIO FOOTPRINTING: $(date '+%d-%m-%Y %H:%M:%S')" | output_txt
            echo -e "🚀 COMANDO: $cmd_raw" | output_txt
            echo -e "${MAGENTA}══════════════════════════════════════════════════${RESET}\n" | output_txt

            # Usamos eval para ejecutar el comando crudo
            eval "$cmd_raw" 2>&1 | output_txt

            [[ "$txt_status" == "ON" ]] && echo -e "\n${VERDE}📄 Reporte guardado en: $reporte_txt${RESET}"
            echo -e "\n${AZUL}--------------------------------------------------${RESET}"
            echo -e "${VERDE}✅ Reconocimiento finalizado.${RESET}"
            
            echo
            read -n 1 -s -r -p $'\e[1;5;32mPulsa cualquier tecla para volver al menú...\e[0m'
        done
        continue
    fi
done
