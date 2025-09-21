#!/usr/bin/env bash
set -euo pipefail

LOG="/tmp/solo-window.log"
> "$LOG"

# Sprawdzenie zależności
if ! command -v hyprctl >/dev/null 2>&1; then
    echo "BŁĄD: hyprctl nie znalezione" | tee -a "$LOG"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "BŁĄD: jq nie znalezione - zainstaluj: sudo pacman -S jq" | tee -a "$LOG"
    exit 1
fi

# Preferowany rozmiar jednego okna
W=1600
H=900

echo "$(date) - Uruchamianie solo-window..." >> "$LOG"

while true; do
    # Pobierz ID aktywnego workspace
    if ! WS=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null); then
        echo "$(date) - Błąd przy pobieraniu activeworkspace" >> "$LOG"
        sleep 0.5
        continue
    fi
    
    if [ -z "$WS" ] || [ "$WS" = "null" ]; then
        echo "$(date) - Nie mogę pobrać ID workspace" >> "$LOG"
        sleep 0.5
        continue
    fi

    # Pobierz listę wszystkich okien
    if ! clients_json=$(hyprctl clients -j 2>/dev/null); then
        echo "$(date) - Błąd przy pobieraniu listy okien" >> "$LOG"
        sleep 0.5
        continue
    fi

    if [ "$clients_json" = "[]" ] || [ -z "$clients_json" ]; then
        sleep 0.1
        continue
    fi

    # Zbierz adresy okien na aktywnym workspace (tylko zwykłe okna, nie specjalne)
    addrs_output=$(printf '%s\n' "$clients_json" | jq -r --argjson ws "$WS" '
        .[] | select(
            .workspace.id == $ws and 
            .class != "" and 
            .title != "" and
            .mapped == true
        ) | .address' 2>/dev/null)

    # Stwórz tablicę adresów
    ADDRS=()
    if [ -n "$addrs_output" ] && [ "$addrs_output" != "null" ]; then
        while IFS= read -r addr; do
            if [ -n "$addr" ]; then
                ADDRS+=("$addr")
            fi
        done <<< "$addrs_output"
    fi

    COUNT=${#ADDRS[@]}
    
    echo "$(date) - WS: $WS, Okien: $COUNT" >> "$LOG"

    if [ "$COUNT" -eq 1 ]; then
        ADDR="${ADDRS[0]}"
        
        # Sprawdź czy okno już jest floating
        is_floating=$(printf '%s\n' "$clients_json" | jq -r --arg addr "$ADDR" '
            .[] | select(.address == $addr) | .floating // false' 2>/dev/null)

        if [ "$is_floating" != "true" ]; then
            echo "$(date) - Ustawiam floating dla: $ADDR" >> "$LOG"
            
            # Wykonuj komendy pojedynczo dla lepszej niezawodności
            if hyprctl dispatch togglefloating "address:$ADDR" 2>>"$LOG"; then
                sleep 0.05
                hyprctl dispatch focuswindow "address:$ADDR" 2>>"$LOG"
                sleep 0.05
                hyprctl dispatch resizewindowpixel "exact $W $H,address:$ADDR" 2>>"$LOG"
                sleep 0.05
                hyprctl dispatch centerwindow "address:$ADDR" 2>>"$LOG"
                echo "$(date) - Sukces: floating ustawione dla $ADDR" >> "$LOG"
            else
                echo "$(date) - Błąd: nie udało się ustawić floating dla $ADDR" >> "$LOG"
            fi
        fi

    elif [ "$COUNT" -gt 1 ]; then
        echo "$(date) - Sprawdzam floating dla $COUNT okien" >> "$LOG"
        
        # Sprawdź które okna są floating i usuń floating
        for addr in "${ADDRS[@]}"; do
            if [ -n "$addr" ]; then
                is_floating=$(printf '%s\n' "$clients_json" | jq -r --arg addr "$addr" '
                    .[] | select(.address == $addr) | .floating // false' 2>/dev/null)
                
                if [ "$is_floating" = "true" ]; then
                    echo "$(date) - Usuwam floating z: $addr" >> "$LOG"
                    hyprctl dispatch togglefloating "address:$addr" 2>>"$LOG" || \
                        echo "$(date) - Błąd przy usuwaniu floating z: $addr" >> "$LOG"
                    sleep 0.02
                fi
            fi
        done
    fi

    sleep 0.1
done
